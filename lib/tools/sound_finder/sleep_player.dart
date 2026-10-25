import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

/// Plays one chunk or a queue of chunks of a sleep session back to back and
/// publishes the audible moment of the night as [playhead].
class SleepPlayer extends ChangeNotifier {
  SleepPlayer() {
    loadSettings();
  }
  static const _logPrefix = '[SleepPlayer]';
  static const _quietPadMs = 300;
  static const _kPlaybackGain = 'sf_sleep_playback_gain';
  static const List<double> playbackGains = [1, 1.5, 2, 3, 4];

  /// Called whenever a chunk starts, so the selection can follow playback.
  void Function(String sessionId, int index)? onChunkStarted;

  SleepSession? _session;
  List<int> _queue = const [];
  int _queuePos = 0;
  bool _continuous = false;
  bool _paused = false;
  double _speed = 1;
  bool _skipQuiet = false;
  double _gain = 1;
  bool _disposed = false;
  AudioSource? _source;
  SoundHandle? _handle;
  StreamSubscription<dynamic>? _soundEventsSub;
  Timer? _ticker;
  Duration? _chunkEnd;
  int _generation = 0;
  final ValueNotifier<DateTime?> _playhead = ValueNotifier(null);

  ValueListenable<DateTime?> get playhead => _playhead;
  String? get sessionId => _session?.id;
  bool get paused => _paused;
  double get speed => _speed;
  bool get skipQuiet => _skipQuiet;
  double get gain => _gain;
  int get queueLength => _queue.length;
  int get queuePosition => _queuePos;

  bool isQueueActive(String id) => _continuous && sessionId == id;

  int? playingIndex(String id) =>
      sessionId == id && _queuePos < _queue.length ? _queue[_queuePos] : null;

  bool isPlayingChunk(String id, int index) =>
      !_continuous && playingIndex(id) == index;

  Future<void> loadSettings() async {
    final raw = await DatabaseService.instance.getSetting(
      SoundFinderTool.config.id,
      _kPlaybackGain,
    );
    final gain = double.tryParse(raw ?? '');
    if (gain == null || !playbackGains.contains(gain)) return;
    if (_disposed) return;
    _gain = gain;
    notifyListeners();
  }

  /// Swaps in a reloaded copy of the playing session.
  void updateSession(SleepSession session) {
    if (session.id == sessionId) _session = session;
  }

  Future<void> playChunk(SleepSession session, int index) async {
    if (isPlayingChunk(session.id, index)) {
      await stop();
      return;
    }
    _begin(session, [index], continuous: false);
    await _startAt(0);
  }

  Future<void> play(
    SleepSession session,
    List<int> queue, {
    int startPos = 0,
  }) async {
    if (queue.isEmpty) return;
    _begin(session, queue, continuous: true);
    await _startAt(startPos.clamp(0, queue.length - 1));
  }

  /// Jumps the running queue to [index]; false when it is not queued.
  bool jumpTo(int index) {
    final pos = _queue.indexOf(index);
    if (!_continuous || pos < 0) return false;
    unawaited(_startAt(pos));
    return true;
  }

  void _begin(
    SleepSession session,
    List<int> queue, {
    required bool continuous,
  }) {
    _session = session;
    _queue = queue;
    _continuous = continuous;
    _paused = false;
  }

  Future<void> _startAt(int pos) async {
    final gen = ++_generation;
    await _releaseVoice();
    if (_disposed || gen != _generation) return;
    final session = _session;
    if (session == null || pos < 0 || pos >= _queue.length) {
      await stop();
      return;
    }
    _queuePos = pos;
    final index = _queue[pos];
    final event = session.data.events[index];
    onChunkStarted?.call(session.id, index);
    notifyListeners();

    final file = session.data.fileFor(event);
    if (!session.hasFile(event) || !await file.exists()) {
      await (_continuous ? _startAt(pos + 1) : stop());
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
      SoLoud.instance.setVolume(handle, _gain);
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
        (_) => _tick(gen, event),
      );
      _tick(gen, event);
    } catch (e) {
      errorLog('$_logPrefix play ${event.fileName}: $e');
      await stop();
    }
  }

  void _tick(int gen, SleepEvent event) {
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
    if (_session == null) return;
    await _startAt(math.min(_queuePos + 1, _queue.length - 1));
  }

  Future<void> previous() async {
    if (_session == null) return;
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

  void setGain(double value) {
    if (!playbackGains.contains(value)) return;
    _gain = value;
    final handle = _handle;
    if (handle != null && SoLoud.instance.getIsValidVoiceHandle(handle)) {
      SoLoud.instance.setVolume(handle, value);
    }
    DatabaseService.instance.setSetting(
      SoundFinderTool.config.id,
      _kPlaybackGain,
      value.toString(),
    );
    notifyListeners();
  }

  Future<void> stop() async {
    _generation++;
    await _releaseVoice();
    _session = null;
    _queue = const [];
    _queuePos = 0;
    _continuous = false;
    _paused = false;
    if (_disposed) return;
    _playhead.value = null;
    notifyListeners();
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

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    onChunkStarted = null;
    unawaited(_releaseVoice());
    _playhead.dispose();
    super.dispose();
  }
}
