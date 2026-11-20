import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'api/dwd_radar.dart';
import 'api/weather_http.dart';
import 'models/radar_viewport.dart';
import 'radar_frame_store.dart';
import 'weather_settings.dart';

/// A decoded WMS image and the Mercator box it covers.
class RadarImage {
  RadarImage(this.image, this.bbox);

  final ui.Image image;
  final Rect bbox;

  void dispose() => image.dispose();
}

/// A fixed square of the map the radar is fetched for. Blocks sit on a grid
/// and depend only on zoom level and position, never on the view size, so the
/// preview and the full-screen radar share them and small pans reuse them.
class RadarBlock {
  const RadarBlock(this.resolution, this.cellX, this.cellY);

  static const int pixels = 1280;

  /// Radar data is a 1 km grid; finer requests only bake in hard blocks.
  static const List<double> levels = [600, 1200, 2400];

  final double resolution;
  final int cellX;
  final int cellY;

  double get span => pixels * resolution;

  /// Fine enough that a block snapped to it still holds a view of 85 % of
  /// its span.
  double get _step => span / 8;

  Rect get bbox {
    final cx = cellX * _step;
    final cy = cellY * _step;
    return Rect.fromLTRB(
      cx - span / 2,
      cy - span / 2,
      cx + span / 2,
      cy + span / 2,
    );
  }

  String get key => '${resolution.round()}:$cellX:$cellY';

  /// Keeps [current] while the view still fits it at the same level, so a
  /// pan across a grid line does not reload every frame.
  static RadarBlock forViewport(RadarViewport vp, {RadarBlock? current}) {
    final level = _levelFor(vp);
    if (current != null &&
        current.resolution == level &&
        current._fits(vp.bounds)) {
      return current;
    }
    final step = pixels * level / 8;
    return RadarBlock(
      level,
      (vp.centerX / step).round(),
      (vp.centerY / step).round(),
    );
  }

  /// The finest level not finer than the view whose block can hold it.
  static double _levelFor(RadarViewport vp) {
    final extent = math.max(vp.bounds.width, vp.bounds.height);
    for (final res in levels) {
      if (res < vp.resolution * .8) continue;
      if (extent <= pixels * res * .85) return res;
    }
    return levels.last;
  }

  bool _fits(Rect b) {
    final box = bbox;
    return b.left >= box.left &&
        b.right <= box.right &&
        b.top >= box.top &&
        b.bottom <= box.bottom;
  }

  @override
  bool operator ==(Object other) =>
      other is RadarBlock &&
      other.resolution == resolution &&
      other.cellX == cellX &&
      other.cellY == cellY;

  @override
  int get hashCode => Object.hash(resolution, cellX, cellY);
}

class WeatherRadarState extends ChangeNotifier {
  WeatherRadarState({
    Future<Uint8List> Function(Uri uri)? fetch,
    RadarFrameStore? store,
    this._lasting,
  }) : _fetch =
           fetch ??
           ((uri) => WeatherHttp.getBytes(uri, timeout: _requestTimeout)),
       _store = store ?? RadarFrameStore();

  static const Duration _requestTimeout = Duration(seconds: 60);
  static const int _concurrency = 6;
  static const int _retries = 2;
  static const int _basePixels = 1536;

  /// Decoded frames kept around the current one; the rest stay compressed.
  static const int _decodeBehind = 2;
  static const int _decodeAhead = 5;
  static const Duration _frameInterval = Duration(milliseconds: 550);
  static const Duration _viewportSettle = Duration(milliseconds: 300);
  static const int _endHoldTicks = 3;

  final Future<Uint8List> Function(Uri uri) _fetch;
  final RadarFrameStore _store;
  final RadarLastingStore? _lasting;

  /// An older saved current frame is too misleading to show while loading.
  static const Duration _lastFrameMaxAge = Duration(hours: 3);

  /// Changes every pan/zoom frame; painters listen to it directly instead of
  /// rebuilding widgets through [notifyListeners].
  final ValueNotifier<RadarViewport?> viewport = ValueNotifier(null);

  RadarTimeline? _timeline;
  DateTime? _timelineFetchedAt;
  bool _loadingTimeline = false;
  bool _failed = false;
  int _index = 0;
  bool _playing = false;
  double _speed = 1;
  int _users = 0;

  /// Views that show the time slider; without one only the current frame loads.
  int _fullUsers = 0;
  final Set<int> _inFlight = {};
  int _endHold = 0;
  Timer? _playTimer;
  Timer? _settleTimer;
  bool _disposed = false;

  RadarBlock? _block;

  /// Bumped when the block changes; base and extras check it.
  int _blockGeneration = 0;

  /// Bumped on block or timeline changes; frame downloads check it.
  int _generation = 0;
  RadarImage? _base;
  RadarImage? _overlay;
  RadarImage? _lightning;
  RadarImage? _warnings;
  final Set<int> _available = {};

  /// Frames the server has no image for, e.g. a nowcast step not computed yet.
  final Set<int> _missing = {};
  final Map<int, RadarImage> _decoded = {};
  final Set<int> _decoding = {};
  RadarImage? _previousFrame;
  final Map<int, double?> _rain = {};

  RadarBaseMap _baseMap = RadarBaseMap.light;
  bool _showLightning = false;
  bool _showWarnings = false;
  ({double lat, double lon})? _focus;

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
  int get loadedCount => _available.length;

  bool get wantsAllFrames => _fullUsers > 0;

  bool get isLoading => wantsAllFrames
      ? _available.length + _missing.length < frameCount
      : !_available.contains(_index) && !_missing.contains(_index);
  bool isLoaded(int i) => _available.contains(i);

  DateTime? get currentTime {
    final t = _timeline;
    return t == null || t.times.isEmpty
        ? null
        : t.times[_index.clamp(0, t.times.length - 1)];
  }

  /// The frame to draw for [index]: its own image once decoded, else the
  /// nearest decoded neighbour, else the last frame of the previous block.
  RadarImage? frameAt(int index) {
    final exact = _decoded[index];
    if (exact != null) return exact;
    for (var d = 1; d <= 3; d++) {
      final near = _decoded[index - d] ?? _decoded[index + d];
      if (near != null) return near;
    }
    return _previousFrame;
  }

  /// Radar intensity in mm/h at the focus per frame; null = not loaded yet.
  /// [double.nan] marks a frame the server has no image for.
  List<double?> get rainSeries => [
    for (var i = 0; i < frameCount; i++)
      _missing.contains(i) ? double.nan : _rain[i],
  ];

  // Lifecycle -----------------------------------------------------------------

  /// Views call this while visible; loading and playback run only then.
  /// A preview passes `full: false` and gets just the current frame.
  void attach({bool full = true}) {
    _users++;
    if (full) _fullUsers++;
    if (_users == 1) {
      unawaited(_ensureTimeline());
    } else if (full && _fullUsers == 1 && _block != null) {
      unawaited(_loadFrames(_generation));
    }
  }

  void detach({bool full = true}) {
    _users = math.max(0, _users - 1);
    if (full) _fullUsers = math.max(0, _fullUsers - 1);
    if (_fullUsers == 0) _stopPlayback();
  }

  /// Drops decoded images and memory when the tool closes; the compressed
  /// frames stay in session temp files for the next open.
  void release() {
    _stopPlayback();
    _settleTimer?.cancel();
    _generation++;
    _blockGeneration++;
    _disposeImages();
    _store.dropMemory();
    // The timeline stays so a reopen serves frames from the store at once.
    _index = _timeline?.nowIndex ?? 0;
    _block = null;
    _focus = null;
    viewport.value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    release();
    unawaited(_store.clear());
    viewport.dispose();
    super.dispose();
  }

  void _disposeImages() {
    for (final img in [
      _base,
      _overlay,
      _lightning,
      _warnings,
      _previousFrame,
      ..._decoded.values,
    ]) {
      img?.dispose();
    }
    _base = _overlay = _lightning = _warnings = _previousFrame = null;
    _decoded.clear();
    _decoding.clear();
    _available.clear();
    _missing.clear();
    _inFlight.clear();
    _rain.clear();
  }

  // Options -------------------------------------------------------------------

  void applySettings(WeatherSettings settings) {
    final layersChanged =
        settings.radarLightning != _showLightning ||
        settings.radarWarnings != _showWarnings;
    _speed = settings.radarSpeed;
    _baseMap = settings.radarBaseMap;
    _showLightning = settings.radarLightning;
    _showWarnings = settings.radarWarnings;
    if (_playing) _restartTimer();
    if (layersChanged && _block != null) {
      unawaited(_loadExtras(_blockGeneration));
    }
    _notify();
  }

  /// Centres on a place when it differs from the current focus.
  void focusOn(double lat, double lon) {
    final previous = _focus;
    if (previous != null && previous.lat == lat && previous.lon == lon) return;
    _focus = (lat: lat, lon: lon);
    final vp = viewport.value;
    if (vp != null) {
      viewport.value = RadarViewport.around(
        lat,
        lon,
        vp.size,
        resolution: vp.resolution,
      );
      _scheduleBlock(immediate: true);
    }
    unawaited(_resampleRain());
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
    _scheduleBlock();
  }

  // Viewport ------------------------------------------------------------------

  void resize(Size size) {
    if (size.isEmpty) return;
    final vp = viewport.value;
    if (vp == null) {
      final f = _focus ?? (lat: 51.0, lon: 10.4);
      viewport.value = RadarViewport.around(f.lat, f.lon, size);
      _scheduleBlock(immediate: true);
    } else if (vp.size != size) {
      viewport.value = vp.copyWith(size: size).clamped();
      _scheduleBlock();
    }
  }

  void panBy(Offset delta) {
    final vp = viewport.value;
    if (vp == null) return;
    viewport.value = vp.panBy(delta);
    _scheduleBlock();
  }

  void zoomAt(double factor, Offset focal) {
    final vp = viewport.value;
    if (vp == null) return;
    viewport.value = vp.zoomAt(factor, focal);
    _scheduleBlock();
  }

  void _scheduleBlock({bool immediate = false}) {
    _settleTimer?.cancel();
    if (immediate) {
      _updateBlock();
    } else {
      _settleTimer = Timer(_viewportSettle, _updateBlock);
    }
  }

  void _updateBlock() {
    final vp = viewport.value;
    if (vp == null || _disposed) return;
    final block = RadarBlock.forViewport(vp, current: _block);
    if (block == _block) return;
    _block = block;
    _blockGeneration++;
    _generation++;
    final current = _decoded.remove(_index) ?? frameAt(_index);
    if (current != null && current != _previousFrame) {
      _previousFrame?.dispose();
      _previousFrame = current;
    }
    for (final img in _decoded.values) {
      if (img != _previousFrame) img.dispose();
    }
    _decoded.clear();
    _decoding.clear();
    _available.clear();
    _missing.clear();
    _inFlight.clear();
    _rain.clear();
    unawaited(_loadBase(_blockGeneration));
    unawaited(_loadExtras(_blockGeneration));
    if (_previousFrame == null) unawaited(_showLastFrame(block));
    if (_timeline != null) unawaited(_loadFrames(_generation));
    _notify();
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
      final old = _timeline;
      _timelineFetchedAt = DateTime.now();
      _failed = false;
      if (old != null &&
          old.latestObserved == timeline.latestObserved &&
          listEquals(old.times, timeline.times)) {
        return;
      }
      final previousTime = currentTime;
      final wasNow = old == null || _index == old.nowIndex;
      _timeline = timeline;
      _index = wasNow || previousTime == null
          ? timeline.nowIndex
          : _closestIndex(previousTime);
      for (final img in _decoded.values) {
        img.dispose();
      }
      _decoded.clear();
      _decoding.clear();
      _available.clear();
      _missing.clear();
      _rain.clear();
      _generation++;
      if (_block != null) unawaited(_loadFrames(_generation));
    } catch (e) {
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
      if (times[i].difference(t).abs() < times[best].difference(t).abs()) {
        best = i;
      }
    }
    return best;
  }

  /// Observed frames never change; nowcast frames belong to one DWD run.
  String _frameKey(RadarBlock block, int i) {
    final t = _timeline!;
    final time = t.times[i];
    final run = t.isForecast(time)
        ? '@${t.latestObserved.toIso8601String()}'
        : '';
    return 'radar:${block.key}:${time.toIso8601String()}$run';
  }

  static bool _isImage(Uint8List b) =>
      b.length > 8 &&
      ((b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) ||
          (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF));

  /// Null when nothing usable arrived. A WMS error document (HTTP 200 with
  /// XML, e.g. for a nowcast step that is not computed yet) is never cached
  /// and not retried.
  Future<Uint8List?> _bytes(
    String key,
    Uri uri, {
    bool cache = true,
    bool lasting = false,
  }) async {
    if (cache) {
      final hit = await _store.read(key);
      if (hit != null && _isImage(hit)) return hit;
    }
    if (lasting) {
      final saved = await _lasting?.read(key);
      if (saved != null && _isImage(saved.bytes)) {
        await _store.write(key, saved.bytes);
        return saved.bytes;
      }
    }
    for (var attempt = 0; attempt <= _retries; attempt++) {
      try {
        final bytes = await _fetch(uri);
        if (!_isImage(bytes)) {
          debugLog(
            '[WeatherRadarState] $key: no image, ${utf8.decode(bytes.take(200).toList(), allowMalformed: true)}',
          );
          return null;
        }
        if (cache) await _store.write(key, bytes);
        if (lasting) unawaited(_lasting?.write(key, bytes));
        return bytes;
      } catch (e) {
        debugLog('[WeatherRadarState] $key attempt ${attempt + 1} failed: $e');
      }
    }
    return null;
  }

  Future<RadarImage?> _decode(Uint8List bytes, Rect bbox) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return RadarImage(frame.image, bbox);
    } catch (e) {
      debugLog('[WeatherRadarState] decode failed: $e');
      return null;
    }
  }

  Future<void> _loadBase(int gen) async {
    final block = _block;
    if (block == null) return;
    final bbox = block.bbox;
    Future<RadarImage?> load(String name, Uri uri) async {
      final bytes = await _bytes('base:$name:${block.key}', uri, lasting: true);
      if (bytes == null || gen != _blockGeneration) return null;
      return _decode(bytes, bbox);
    }

    final results = await Future.wait([
      load(
        'satellite',
        DwdRadarClient.mapUrl(
          layers: const [DwdRadarClient.satelliteLayer],
          bbox: bbox,
          width: _basePixels,
          height: _basePixels,
          jpeg: true,
        ),
      ),
      load(
        'borders',
        DwdRadarClient.overlayUrl(
          bbox: bbox,
          width: _basePixels,
          height: _basePixels,
        ),
      ),
    ]);
    if (gen != _blockGeneration || _disposed) {
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

  /// Lightning and warnings change constantly, so they skip the cache.
  Future<void> _loadExtras(int gen) async {
    final block = _block;
    if (block == null) return;
    final bbox = block.bbox;
    Future<RadarImage?> load(String layer) async {
      final uri = DwdRadarClient.mapUrl(
        layers: [layer],
        bbox: bbox,
        width: RadarBlock.pixels,
        height: RadarBlock.pixels,
      );
      final bytes = await _bytes(layer, uri, cache: false);
      if (bytes == null || gen != _blockGeneration) return null;
      return _decode(bytes, bbox);
    }

    if (_showLightning) {
      final img = await load(DwdRadarClient.lightningLayer);
      if (img != null && gen == _blockGeneration) {
        _lightning?.dispose();
        _lightning = img;
      }
    }
    if (_showWarnings) {
      final img = await load(DwdRadarClient.warningsLayer);
      if (img != null && gen == _blockGeneration) {
        _warnings?.dispose();
        _warnings = img;
      }
    }
    _notify();
  }

  /// Current frame first, then quarter-hours, then the rest, each nearest to
  /// now first, so the slider is usable long before everything has arrived.
  Future<void> _loadFrames(int gen) async {
    final timeline = _timeline;
    final block = _block;
    if (timeline == null || block == null) return;
    final now = timeline.nowIndex;
    int rank(int i) => i == _index
        ? 0
        : ((i - now) % 3 == 0 ? 1 : ((i - now) % 2 == 0 ? 2 : 3));
    final order = List.generate(timeline.times.length, (i) => i)
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : (a - now).abs().compareTo((b - now).abs());
      });
    final wanted = wantsAllFrames ? order : order.where((i) => i == _index);
    final queue = Queue.of(
      wanted.where(
        (i) =>
            !_available.contains(i) &&
            !_missing.contains(i) &&
            !_inFlight.contains(i),
      ),
    );

    Future<void> worker() async {
      while (queue.isNotEmpty && gen == _generation && !_disposed) {
        final i = queue.removeFirst();
        if (!_inFlight.add(i)) continue;
        final uri = DwdRadarClient.mapUrl(
          layers: const [DwdRadarClient.radarLayer],
          bbox: block.bbox,
          width: RadarBlock.pixels,
          height: RadarBlock.pixels,
          time: timeline.times[i],
        );
        final bytes = await _bytes(_frameKey(block, i), uri);
        _inFlight.remove(i);
        if (gen != _generation) continue;
        final img = bytes == null ? null : await _decode(bytes, block.bbox);
        if (img == null) {
          if (gen == _generation) {
            _missing.add(i);
            _notify();
          }
          continue;
        }
        if (gen != _generation || _disposed) {
          img.dispose();
          continue;
        }
        _available.add(i);
        if (i == timeline.nowIndex) {
          unawaited(_lasting?.write(_lastFrameKey(block), bytes!));
        }
        _rain[i] = await _sampleRain(img);
        if (_inWindow(i) && !_decoded.containsKey(i)) {
          _decoded[i] = img;
          if (i == _index) _dropPrevious();
        } else {
          img.dispose();
        }
        _notify();
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));
  }

  String _lastFrameKey(RadarBlock block) => 'last:${block.key}';

  /// Bridges the wait for the first download with the frame saved last time.
  Future<void> _showLastFrame(RadarBlock block) async {
    final saved = await _lasting?.read(_lastFrameKey(block));
    if (saved == null ||
        DateTime.now().difference(saved.savedAt) > _lastFrameMaxAge) {
      return;
    }
    final img = await _decode(saved.bytes, block.bbox);
    if (img == null) return;
    if (_disposed ||
        block != _block ||
        _previousFrame != null ||
        _decoded.containsKey(_index)) {
      img.dispose();
      return;
    }
    _previousFrame = img;
    _notify();
  }

  void _dropPrevious() {
    final prev = _previousFrame;
    if (prev != null && !_decoded.containsValue(prev)) prev.dispose();
    _previousFrame = null;
  }

  bool _inWindow(int i) =>
      i >= _index - _decodeBehind && i <= _index + _decodeAhead;

  /// Keeps decoded only the frames around [_index], decoding missing ones
  /// from the compressed store.
  void _syncWindow() {
    final block = _block;
    if (block == null || _timeline == null) return;
    for (final i in _decoded.keys.toList()) {
      if (!_inWindow(i)) _decoded.remove(i)!.dispose();
    }
    final gen = _generation;
    for (var i = _index - _decodeBehind; i <= _index + _decodeAhead; i++) {
      if (i < 0 || i >= frameCount || !_available.contains(i)) continue;
      if (_decoded.containsKey(i) || !_decoding.add(i)) continue;
      unawaited(() async {
        final bytes = await _store.read(_frameKey(block, i));
        final img = bytes == null ? null : await _decode(bytes, block.bbox);
        _decoding.remove(i);
        if (img == null) return;
        if (gen != _generation || !_inWindow(i) || _decoded.containsKey(i)) {
          img.dispose();
          return;
        }
        _decoded[i] = img;
        if (i == _index) _dropPrevious();
        _notify();
      }());
    }
  }

  Future<double?> _sampleRain(RadarImage img) async {
    final f = _focus;
    if (f == null) return null;
    final x = Mercator.x(f.lon);
    final y = Mercator.y(f.lat);
    final b = img.bbox;
    if (x < b.left || x > b.right || y < b.top || y > b.bottom) return null;
    final w = img.image.width;
    final h = img.image.height;
    final px = ((x - b.left) / b.width * w).floor().clamp(0, w - 1);
    final py = ((b.bottom - y) / b.height * h).floor().clamp(0, h - 1);
    final data = await img.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    double? best;
    // A 3×3 neighbourhood so a single noisy pixel does not decide.
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final o =
            ((py + dy).clamp(0, h - 1) * w + (px + dx).clamp(0, w - 1)) * 4;
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

  Future<void> _resampleRain() async {
    final block = _block;
    if (block == null || _timeline == null) return;
    _rain.clear();
    final gen = _generation;
    for (final i in _available.toList()) {
      final bytes = await _store.read(_frameKey(block, i));
      if (bytes == null || gen != _generation) continue;
      final img = await _decode(bytes, block.bbox);
      if (img == null) continue;
      _rain[i] = await _sampleRain(img);
      img.dispose();
    }
    _notify();
  }

  // Playback ------------------------------------------------------------------

  void seek(int index) {
    final count = frameCount;
    if (count == 0) return;
    _index = index.clamp(0, count - 1);
    _syncWindow();
    if (!wantsAllFrames && !_available.contains(_index)) {
      unawaited(_loadFrames(_generation));
    }
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
    int? next;
    for (var i = _index + 1; i < count; i++) {
      if (_available.contains(i)) {
        next = i;
        break;
      }
    }
    if (next == null) {
      if (_endHold++ < _endHoldTicks) return;
      _endHold = 0;
      next = _available.isEmpty ? 0 : _available.reduce(math.min);
    }
    seek(next);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
