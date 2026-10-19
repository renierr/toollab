import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:health_connector/health_connector.dart' as hc;
import 'package:tool_lab/helpers/debug_log.dart';

import '../health_dashboard/store/health_schema.dart';
import '../health_dashboard/store/health_store.dart';
import 'audio/sleep_chunk_analyzer.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

class SleepStageBand {
  const SleepStageBand({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// Backs the sleep sessions page: the session list, per-session selection and
/// category filter, and one shared player for single chunks and play-all.
class SleepSessionsState extends ChangeNotifier {
  SleepSessionsState() {
    SleepSessionStore.revision.addListener(_onStoreChanged);
    SleepSessionStore.analysisProgress.addListener(notifyListeners);
    load();
  }

  static const _logPrefix = '[SleepSessions]';
  static const _quietPadMs = 300;

  List<SleepSession> _sessions = const [];
  bool _loading = true;
  bool _disposed = false;
  final Map<String, int> _selected = {};
  final Map<String, Set<SleepSoundCategory?>> _filters = {};
  final Map<String, List<SleepStageBand>> _healthStages = {};
  final Set<String> _healthLoading = {};

  List<SleepSession> get sessions => _sessions;
  bool get loading => _loading;
  int get totalWavBytes => _sessions.fold(0, (a, s) => a + s.wavBytes);
  int get totalJsonBytes => _sessions.fold(0, (a, s) => a + s.jsonBytes);

  double? analysisProgress(String id) =>
      SleepSessionStore.analysisProgress.value[id];

  List<SleepStageBand> healthStages(String id) => _healthStages[id] ?? const [];
  bool healthLoading(String id) => _healthLoading.contains(id);

  SleepSession? _byId(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> load() async {
    final list = await SleepSessionStore.list();
    if (_disposed) return;
    _sessions = list;
    _loading = false;
    notifyListeners();
  }

  void _onStoreChanged() => unawaited(load());

  // --- Selection & filter ---

  int? selectedIndex(String id) => _selected[id];

  void select(SleepSession session, int index) {
    if (index < 0 || index >= session.data.events.length) return;
    final playingHere = _playSessionId == session.id && _continuous;
    if (_selected[session.id] == index && !playingHere) return;
    _selected[session.id] = index;
    if (playingHere) {
      final pos = _queue.indexOf(index);
      if (pos >= 0) {
        unawaited(_startAt(pos));
      } else {
        unawaited(playAll(session, from: index));
      }
    }
    notifyListeners();
  }

  void step(SleepSession session, int delta) {
    final visible = visibleIndices(session);
    if (visible.isEmpty) return;
    final current = _selected[session.id];
    final pos = current == null ? -1 : visible.indexOf(current);
    final next = pos < 0
        ? (delta > 0 ? 0 : visible.length - 1)
        : (pos + delta).clamp(0, visible.length - 1);
    select(session, visible[next]);
  }

  Set<SleepSoundCategory?> filter(String id) => _filters[id] ?? const {};

  void toggleFilter(String id, SleepSoundCategory? category) {
    final set = {...filter(id)};
    if (!set.remove(category)) set.add(category);
    _filters[id] = set;
    notifyListeners();
  }

  void clearFilter(String id) {
    _filters.remove(id);
    notifyListeners();
  }

  bool matches(SleepSession session, SleepEvent e) {
    final f = filter(session.id);
    return f.isEmpty || f.contains(e.analysis?.category);
  }

  List<int> visibleIndices(SleepSession session) => [
    for (var i = 0; i < session.data.events.length; i++)
      if (matches(session, session.data.events[i])) i,
  ];

  // --- Playback ---

  String? _playSessionId;
  List<int> _queue = const [];
  int _queuePos = 0;
  bool _continuous = false;
  bool _paused = false;
  double _speed = 1;
  bool _skipQuiet = false;
  AudioSource? _source;
  SoundHandle? _handle;
  StreamSubscription<dynamic>? _soundEventsSub;
  Timer? _ticker;
  Duration? _chunkEnd;
  int _generation = 0;
  final ValueNotifier<DateTime?> _playhead = ValueNotifier(null);

  /// Wall-clock moment of the night currently audible, for the timeline.
  ValueListenable<DateTime?> get playhead => _playhead;
  String? get playingSessionId => _playSessionId;
  bool get continuous => _continuous;
  bool get paused => _paused;
  double get speed => _speed;
  bool get skipQuiet => _skipQuiet;
  int get queueLength => _queue.length;
  int get queuePosition => _queuePos;

  int? playingIndex(String id) =>
      _playSessionId == id && _queuePos < _queue.length
      ? _queue[_queuePos]
      : null;

  bool isPlayingChunk(String id, int index) =>
      !_continuous && playingIndex(id) == index;

  Future<void> playChunk(SleepSession session, int index) async {
    if (isPlayingChunk(session.id, index)) {
      await stop();
      return;
    }
    _selected[session.id] = index;
    _begin(session.id, [index], continuous: false);
    await _startAt(0);
  }

  Future<void> playAll(SleepSession session, {int? from}) async {
    final queue = visibleIndices(session);
    if (queue.isEmpty) return;
    var pos = 0;
    if (from != null) {
      pos = queue.indexWhere((i) => i >= from);
      if (pos < 0) pos = 0;
    }
    _begin(session.id, queue, continuous: true);
    await _startAt(pos);
  }

  void _begin(String id, List<int> queue, {required bool continuous}) {
    _playSessionId = id;
    _queue = queue;
    _continuous = continuous;
    _paused = false;
  }

  Future<void> _startAt(int pos) async {
    final gen = ++_generation;
    await _releaseVoice();
    if (_disposed || gen != _generation) return;
    final session = _playSessionId == null ? null : _byId(_playSessionId!);
    if (session == null || pos < 0 || pos >= _queue.length) {
      await stop();
      return;
    }
    _queuePos = pos;
    final index = _queue[pos];
    final event = session.data.events[index];
    _selected[session.id] = index;
    notifyListeners();

    final file = session.data.fileFor(event);
    if (!session.hasFile(event) || !await file.exists()) {
      if (_continuous) {
        await _startAt(pos + 1);
      } else {
        await stop();
      }
      return;
    }
    try {
      if (!SoLoud.instance.isInitialized) await SoLoud.instance.init();
      final source = await SoLoud.instance.loadFile(file.path);
      if (gen != _generation) {
        unawaited(SoLoud.instance.disposeSource(source));
        return;
      }
      final handle = SoLoud.instance.play(source, paused: true);
      SoLoud.instance.setRelativePlaySpeed(handle, _speed);
      final analysis = event.analysis;
      _chunkEnd = null;
      if (_skipQuiet && analysis != null && analysis.bursts > 0) {
        final from = math.max(0, analysis.firstActiveMs - _quietPadMs);
        if (from > 0) {
          SoLoud.instance.seek(handle, Duration(milliseconds: from));
        }
        _chunkEnd = Duration(milliseconds: analysis.lastActiveMs + _quietPadMs);
      }
      SoLoud.instance.setPause(handle, _paused);
      _source = source;
      _handle = handle;
      _soundEventsSub = source.soundEvents.listen((e) {
        if (e.handle == handle &&
            e.event == SoundEventType.handleIsNoMoreValid &&
            gen == _generation) {
          unawaited(_advance());
        }
      });
      _ticker = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _tick(gen, session.data, event),
      );
      _tick(gen, session.data, event);
    } catch (e) {
      errorLog('$_logPrefix play ${event.fileName}: $e');
      await stop();
    }
  }

  void _tick(int gen, SleepSessionData data, SleepEvent event) {
    final handle = _handle;
    if (gen != _generation || handle == null) return;
    if (!SoLoud.instance.getIsValidVoiceHandle(handle)) return;
    final pos = SoLoud.instance.getPosition(handle);
    _playhead.value = event.startedAt.add(pos);
    final end = _chunkEnd;
    if (end != null && pos >= end) unawaited(_advance());
  }

  Future<void> _advance() async {
    if (_continuous && _queuePos + 1 < _queue.length) {
      await _startAt(_queuePos + 1);
    } else {
      await stop();
    }
  }

  Future<void> next() async {
    if (_playSessionId == null) return;
    await _startAt(math.min(_queuePos + 1, _queue.length - 1));
  }

  Future<void> previous() async {
    if (_playSessionId == null) return;
    await _startAt(math.max(0, _queuePos - 1));
  }

  void togglePause() {
    final handle = _handle;
    if (handle == null) return;
    _paused = !_paused;
    SoLoud.instance.setPause(handle, _paused);
    notifyListeners();
  }

  void setSpeed(double value) {
    _speed = value;
    final handle = _handle;
    if (handle != null) SoLoud.instance.setRelativePlaySpeed(handle, value);
    notifyListeners();
  }

  void setSkipQuiet(bool value) {
    _skipQuiet = value;
    notifyListeners();
  }

  Future<void> stop() async {
    _generation++;
    await _releaseVoice();
    _playSessionId = null;
    _queue = const [];
    _queuePos = 0;
    _paused = false;
    _playhead.value = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> _releaseVoice() async {
    _ticker?.cancel();
    _ticker = null;
    await _soundEventsSub?.cancel();
    _soundEventsSub = null;
    final h = _handle;
    final s = _source;
    _handle = null;
    _source = null;
    try {
      if (h != null && SoLoud.instance.getIsValidVoiceHandle(h)) {
        await SoLoud.instance.stop(h);
      }
      if (s != null) await SoLoud.instance.disposeSource(s);
    } catch (e) {
      errorLog('$_logPrefix release: $e');
    }
  }

  // --- Edits ---

  Future<void> annotate(SleepSession session, SleepEvent event, String text) =>
      SleepSessionStore.update(session.path, (data) {
        for (final e in data.events) {
          if (e.fileName == event.fileName) {
            e.annotation = text.trim().isEmpty ? null : text.trim();
          }
        }
      });

  Future<void> analyze(SleepSession session) =>
      SleepSessionStore.analyze(session);

  Future<void> delete(SleepSession session) async {
    if (_playSessionId == session.id) await stop();
    _selected.remove(session.id);
    _filters.remove(session.id);
    await SleepSessionStore.delete(session);
  }

  /// Returns whether any sleep stage was found.
  Future<bool> loadHealthStages(SleepSession session) async {
    _healthLoading.add(session.id);
    notifyListeners();
    final start = session.data.startedAt;
    final end = session.data.endedAt;
    final bands = <SleepStageBand>[];
    // Prefer the already-synced Health Dashboard store (no extra permissions).
    try {
      final sessions = await HealthStore.instance.sessions(
        kind: HealthSchema.sessionKindSleep,
        from: start.millisecondsSinceEpoch,
        to: end.millisecondsSinceEpoch,
      );
      for (final s in sessions) {
        bands.add(
          SleepStageBand(
            start: DateTime.fromMillisecondsSinceEpoch(s.t0),
            end: DateTime.fromMillisecondsSinceEpoch(s.t1),
          ),
        );
      }
    } catch (e) {
      errorLog('$_logPrefix health store: $e');
    }
    if (bands.isEmpty && Platform.isAndroid) {
      try {
        final connector = await hc.HealthConnector.create();
        await connector.requestPermissions([
          hc.HealthDataType.sleepSession.readPermission,
        ]);
        final req = hc.HealthDataType.sleepSession.readInTimeRange(
          startTime: start,
          endTime: end,
        );
        final resp = await connector.readRecords(req);
        for (final r in (resp.records as List).cast<hc.HealthRecord>()) {
          if (r is hc.IntervalHealthRecord) {
            bands.add(SleepStageBand(start: r.startTime, end: r.endTime));
          }
        }
      } catch (e) {
        errorLog('$_logPrefix health connect: $e');
      }
    }
    if (_disposed) return bands.isNotEmpty;
    _healthStages[session.id] = bands;
    _healthLoading.remove(session.id);
    notifyListeners();
    return bands.isNotEmpty;
  }

  @override
  void dispose() {
    _disposed = true;
    SleepSessionStore.revision.removeListener(_onStoreChanged);
    SleepSessionStore.analysisProgress.removeListener(notifyListeners);
    _generation++;
    unawaited(_releaseVoice());
    _playhead.dispose();
    super.dispose();
  }
}
