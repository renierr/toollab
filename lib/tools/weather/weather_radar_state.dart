import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'api/dwd_radar.dart';
import 'api/weather_http.dart';
import 'models/radar_viewport.dart';
import 'weather_settings.dart';

/// A decoded WMS image and the Mercator box it covers.
class RadarImage {
  RadarImage(this.image, this.bbox);

  final ui.Image image;
  final Rect bbox;

  void dispose() => image.dispose();
}

class WeatherRadarState extends ChangeNotifier {
  WeatherRadarState({Future<Uint8List> Function(Uri uri)? fetch})
    : _fetch = fetch ?? WeatherHttp.getBytes;

  static const int _concurrency = 6;
  static const int _maxRadarPixels = 900;
  static const int _maxBasePixels = 1400;
  static const Duration _frameInterval = Duration(milliseconds: 550);
  static const Duration _viewportSettle = Duration(milliseconds: 350);
  static const int _endHoldTicks = 3;

  final Future<Uint8List> Function(Uri uri) _fetch;

  /// Changes every pan/zoom frame; painters listen to it directly instead of
  /// rebuilding widgets through [notifyListeners].
  final ValueNotifier<RadarViewport?> viewport = ValueNotifier(null);

  RadarTimeline? _timeline;
  int _index = 0;
  bool _playing = false;
  double _speed = 1;
  bool _failed = false;
  bool _loadingTimeline = false;
  int _users = 0;
  int _generation = 0;
  int _endHold = 0;
  Timer? _playTimer;
  Timer? _settleTimer;
  DateTime? _timelineFetchedAt;

  Rect? _coverage;
  double? _coverageResolution;
  RadarImage? _base;
  RadarImage? _overlay;
  RadarImage? _lightning;
  RadarImage? _warnings;
  final Map<int, RadarImage> _frames = {};
  final Map<int, RadarImage> _staleFrames = {};
  final Map<int, double?> _rain = {};
  final Set<int> _pending = {};

  RadarBaseMap _baseMap = RadarBaseMap.light;
  bool _showLightning = false;
  bool _showWarnings = false;
  ({double lat, double lon})? _focus;
  bool _disposed = false;

  RadarTimeline? get timeline => _timeline;
  int get index => _index;
  bool get isPlaying => _playing;
  double get speed => _speed;
  bool get failed => _failed;
  RadarBaseMap get baseMap => _baseMap;
  RadarImage? get base => _base;
  RadarImage? get overlay => _overlay;
  RadarImage? get lightning => _showLightning ? _lightning : null;
  RadarImage? get warnings => _showWarnings ? _warnings : null;
  ({double lat, double lon})? get focus => _focus;

  int get frameCount => _timeline?.times.length ?? 0;
  int get loadedCount => _frames.length;
  bool isLoaded(int i) => _frames.containsKey(i);

  DateTime? get currentTime {
    final t = _timeline;
    return t == null || t.times.isEmpty
        ? null
        : t.times[_index.clamp(0, t.times.length - 1)];
  }

  /// Frame for [index], falling back to the same time of the previous view.
  RadarImage? frameAt(int index) => _frames[index] ?? _staleFrames[index];

  /// Radar intensity in mm/h at the focus per frame; null = not loaded yet.
  List<double?> get rainSeries => [
    for (var i = 0; i < frameCount; i++) _rain[i],
  ];

  bool hasRainValue(int i) => _rain.containsKey(i);

  // Lifecycle -----------------------------------------------------------------

  /// Views call this while visible; loading and playback run only then.
  void attach() {
    _users++;
    if (_users == 1) unawaited(_ensureTimeline());
  }

  void detach() {
    _users = math.max(0, _users - 1);
    if (_users == 0) _stopPlayback();
  }

  /// Drops every image when the tool closes.
  void release() {
    _stopPlayback();
    _settleTimer?.cancel();
    _generation++;
    _disposeAll();
    _timeline = null;
    _timelineFetchedAt = null;
    _coverage = null;
    _focus = null;
    viewport.value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    release();
    viewport.dispose();
    super.dispose();
  }

  void _disposeAll() {
    for (final img in [
      _base,
      _overlay,
      _lightning,
      _warnings,
      ..._frames.values,
      ..._staleFrames.values,
    ]) {
      img?.dispose();
    }
    _base = _overlay = _lightning = _warnings = null;
    _frames.clear();
    _staleFrames.clear();
    _rain.clear();
    _pending.clear();
  }

  // Options -------------------------------------------------------------------

  void applySettings(WeatherSettings settings) {
    final changedLayers =
        settings.radarLightning != _showLightning ||
        settings.radarWarnings != _showWarnings;
    _speed = settings.radarSpeed;
    _baseMap = settings.radarBaseMap;
    _showLightning = settings.radarLightning;
    _showWarnings = settings.radarWarnings;
    if (_playing) _restartTimer();
    if (changedLayers && _coverage != null) unawaited(_loadExtras(_generation));
    _notify();
  }

  /// Centres on a place when it differs from the current focus.
  void focusOn(double lat, double lon) {
    final previous = _focus;
    if (previous != null && previous.lat == lat && previous.lon == lon) return;
    _focus = (lat: lat, lon: lon);
    _rain.clear();
    final vp = viewport.value;
    if (vp != null) {
      viewport.value = RadarViewport.around(
        lat,
        lon,
        vp.size,
        resolution: vp.resolution,
      );
      _scheduleCoverage(immediate: true);
    }
    unawaited(_recomputeRain());
    _notify();
  }

  void recenter() {
    final f = _focus;
    final vp = viewport.value;
    if (f == null || vp == null) return;
    viewport.value = RadarViewport.around(
      f.lat,
      f.lon,
      vp.size,
      resolution: math.min(vp.resolution, 1200),
    );
    _scheduleCoverage();
  }

  // Viewport ------------------------------------------------------------------

  void resize(Size size) {
    if (size.isEmpty) return;
    final vp = viewport.value;
    if (vp == null) {
      final f = _focus ?? (lat: 51.0, lon: 10.4);
      viewport.value = RadarViewport.around(f.lat, f.lon, size);
      _scheduleCoverage(immediate: true);
    } else if (vp.size != size) {
      viewport.value = vp.copyWith(size: size).clamped();
      _scheduleCoverage();
    }
  }

  void panBy(Offset delta) {
    final vp = viewport.value;
    if (vp == null) return;
    viewport.value = vp.panBy(delta);
    _scheduleCoverage();
  }

  void zoomAt(double factor, Offset focal) {
    final vp = viewport.value;
    if (vp == null) return;
    viewport.value = vp.zoomAt(factor, focal);
    _scheduleCoverage();
  }

  void _scheduleCoverage({bool immediate = false}) {
    _settleTimer?.cancel();
    if (immediate) {
      _updateCoverage();
    } else {
      _settleTimer = Timer(_viewportSettle, _updateCoverage);
    }
  }

  void _updateCoverage() {
    final vp = viewport.value;
    if (vp == null || _disposed) return;
    final coverage = _coverage;
    final res = _coverageResolution;
    final ratio = res == null ? 0 : vp.resolution / res;
    final fits =
        coverage != null &&
        _contains(coverage, vp.bounds) &&
        ratio > .6 &&
        ratio < 1.7;
    if (fits) return;

    final b = vp.bounds;
    final next = Rect.fromLTRB(
      b.left - b.width / 2,
      b.top - b.height / 2,
      b.right + b.width / 2,
      b.bottom + b.height / 2,
    );
    _coverage = next;
    _coverageResolution = vp.resolution;
    _generation++;
    for (final entry in _frames.entries) {
      _staleFrames.remove(entry.key)?.dispose();
      _staleFrames[entry.key] = entry.value;
    }
    _frames.clear();
    _pending.clear();
    _rain.clear();
    final gen = _generation;
    unawaited(_loadBase(gen));
    unawaited(_loadExtras(gen));
    if (_timeline != null) unawaited(_loadFrames(gen));
  }

  static bool _contains(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.right <= outer.right &&
      inner.top >= outer.top &&
      inner.bottom <= outer.bottom;

  (int, int) _pixels(Rect bbox, int cap) {
    final res = _coverageResolution ?? 1000;
    var w = bbox.width / res;
    var h = bbox.height / res;
    final scale = math.min(1.0, cap / math.max(w, h));
    w *= scale;
    h *= scale;
    return (math.max(1, w.round()), math.max(1, h.round()));
  }

  // Loading -------------------------------------------------------------------

  Future<void> _ensureTimeline() async {
    final fetchedAt = _timelineFetchedAt;
    final fresh =
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < const Duration(minutes: 5);
    if (fresh || _loadingTimeline) return;
    _loadingTimeline = true;
    try {
      final bytes = await _fetch(DwdRadarClient.capabilitiesUrl());
      final timeline = RadarTimeline.parseCapabilities(
        utf8.decode(bytes, allowMalformed: true),
      );
      if (_disposed) return;
      final previousTime = currentTime;
      _timeline = timeline;
      _timelineFetchedAt = DateTime.now();
      _failed = false;
      _index = previousTime == null
          ? timeline.nowIndex
          : _closestIndex(previousTime);
      for (final img in [..._frames.values, ..._staleFrames.values]) {
        img.dispose();
      }
      _frames.clear();
      _staleFrames.clear();
      _rain.clear();
      _pending.clear();
      _generation++;
      final gen = _generation;
      if (_coverage != null) {
        unawaited(_loadFrames(gen));
        unawaited(_loadExtras(gen));
      }
    } on WeatherException catch (e) {
      debugLog('[WeatherRadarState] timeline failed: $e');
      _failed = _timeline == null;
    } finally {
      _loadingTimeline = false;
      _notify();
    }
  }

  int _closestIndex(DateTime t) {
    final times = _timeline!.times;
    var best = 0;
    for (var i = 0; i < times.length; i++) {
      if ((times[i].difference(t)).abs() < (times[best].difference(t)).abs()) {
        best = i;
      }
    }
    return best;
  }

  Future<RadarImage?> _download(Uri uri, Rect bbox, int gen) async {
    try {
      final bytes = await _fetch(uri);
      if (gen != _generation || _disposed) return null;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (gen != _generation || _disposed) {
        frame.image.dispose();
        return null;
      }
      return RadarImage(frame.image, bbox);
    } catch (e) {
      debugLog('[WeatherRadarState] $uri failed: $e');
      return null;
    }
  }

  Future<void> _loadBase(int gen) async {
    final bbox = _coverage!;
    final (w, h) = _pixels(bbox, _maxBasePixels);
    final results = await Future.wait([
      _download(
        DwdRadarClient.mapUrl(
          layers: const [DwdRadarClient.satelliteLayer],
          bbox: bbox,
          width: w,
          height: h,
        ),
        bbox,
        gen,
      ),
      _download(
        DwdRadarClient.overlayUrl(bbox: bbox, width: w, height: h),
        bbox,
        gen,
      ),
    ]);
    if (gen != _generation) {
      for (final r in results) {
        r?.dispose();
      }
      return;
    }
    if (results[0] != null) {
      _base?.dispose();
      _base = results[0];
    }
    if (results[1] != null) {
      _overlay?.dispose();
      _overlay = results[1];
    }
    _notify();
  }

  Future<void> _loadExtras(int gen) async {
    final bbox = _coverage;
    if (bbox == null) return;
    final (w, h) = _pixels(bbox, _maxRadarPixels);
    if (_showLightning) {
      final img = await _download(
        DwdRadarClient.mapUrl(
          layers: const [DwdRadarClient.lightningLayer],
          bbox: bbox,
          width: w,
          height: h,
        ),
        bbox,
        gen,
      );
      if (img != null) {
        _lightning?.dispose();
        _lightning = img;
      }
    }
    if (_showWarnings) {
      final img = await _download(
        DwdRadarClient.mapUrl(
          layers: const [DwdRadarClient.warningsLayer],
          bbox: bbox,
          width: w,
          height: h,
        ),
        bbox,
        gen,
      );
      if (img != null) {
        _warnings?.dispose();
        _warnings = img;
      }
    }
    _notify();
  }

  /// Loads the current frame first, then quarter-hours, then the rest, each
  /// nearest to now first, so the slider is usable long before all arrive.
  Future<void> _loadFrames(int gen) async {
    final timeline = _timeline;
    final bbox = _coverage;
    if (timeline == null || bbox == null) return;
    final now = timeline.nowIndex;
    int rank(int i) => i == _index
        ? 0
        : ((i - now) % 3 == 0 ? 1 : ((i - now) % 2 == 0 ? 2 : 3));
    final order = List.generate(timeline.times.length, (i) => i)
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : (a - now).abs().compareTo((b - now).abs());
      });
    final queue = Queue.of(
      order.where((i) => !_frames.containsKey(i) && !_pending.contains(i)),
    );
    final (w, h) = _pixels(bbox, _maxRadarPixels);

    Future<void> worker() async {
      while (queue.isNotEmpty && gen == _generation && !_disposed) {
        final i = queue.removeFirst();
        _pending.add(i);
        final img = await _download(
          DwdRadarClient.mapUrl(
            layers: const [DwdRadarClient.radarLayer],
            bbox: bbox,
            width: w,
            height: h,
            time: timeline.times[i],
          ),
          bbox,
          gen,
        );
        _pending.remove(i);
        if (img == null || gen != _generation) continue;
        _frames[i] = img;
        _staleFrames.remove(i)?.dispose();
        _rain[i] = await _sampleRain(img);
        _notify();
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));
  }

  Future<double?> _sampleRain(RadarImage img) async {
    final f = _focus;
    if (f == null) return null;
    final x = Mercator.x(f.lon);
    final y = Mercator.y(f.lat);
    final b = img.bbox;
    if (x < b.left || x > b.right || y < b.top || y > b.bottom) return null;
    final px = ((x - b.left) / b.width * img.image.width).floor().clamp(
      0,
      img.image.width - 1,
    );
    final py = ((b.bottom - y) / b.height * img.image.height).floor().clamp(
      0,
      img.image.height - 1,
    );
    final data = await img.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    double? best;
    // A 3×3 neighbourhood so a single noisy pixel does not decide.
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final sx = (px + dx).clamp(0, img.image.width - 1);
        final sy = (py + dy).clamp(0, img.image.height - 1);
        final o = (sy * img.image.width + sx) * 4;
        final v = RadarPalette.intensity(
          data.getUint8(o),
          data.getUint8(o + 1),
          data.getUint8(o + 2),
          data.getUint8(o + 3),
        );
        if (v != null && (best == null || v > best)) best = v;
      }
    }
    return best ?? 0;
  }

  Future<void> _recomputeRain() async {
    final gen = _generation;
    for (final entry in _frames.entries.toList()) {
      final value = await _sampleRain(entry.value);
      if (gen != _generation) return;
      _rain[entry.key] = value;
    }
    _notify();
  }

  // Playback ------------------------------------------------------------------

  void seek(int index) {
    final count = frameCount;
    if (count == 0) return;
    _index = index.clamp(0, count - 1);
    _notify();
  }

  void step(int delta) => seek(_index + delta);

  void jumpToNow() {
    final t = _timeline;
    if (t != null) seek(t.nowIndex);
  }

  void togglePlay() => _playing ? _stopPlayback() : _startPlayback();

  void _startPlayback() {
    if (frameCount == 0) return;
    _playing = true;
    _endHold = 0;
    _restartTimer();
    _notify();
  }

  void _stopPlayback() {
    _playTimer?.cancel();
    _playTimer = null;
    if (_playing) {
      _playing = false;
      _notify();
    }
  }

  void _restartTimer() {
    _playTimer?.cancel();
    final ms = (_frameInterval.inMilliseconds / _speed).round();
    _playTimer = Timer.periodic(Duration(milliseconds: ms), (_) => _tick());
  }

  void _tick() {
    final count = frameCount;
    if (count == 0) return;
    if (_index >= count - 1) {
      if (_endHold++ < _endHoldTicks) return;
      _endHold = 0;
      _index = _nextLoaded(-1) ?? 0;
    } else {
      _index = _nextLoaded(_index) ?? _index;
      if (_nextLoaded(_index) == null) _index = count - 1;
    }
    _notify();
  }

  int? _nextLoaded(int from) {
    for (var i = from + 1; i < frameCount; i++) {
      if (frameAt(i) != null) return i;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
