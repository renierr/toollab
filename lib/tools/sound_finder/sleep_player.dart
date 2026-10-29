import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';

import 'audio/sleep_playback_peak.dart';
import 'audio/sleep_playback_ranges.dart';
import 'config.dart';
import 'sleep_session_data.dart';
import 'sleep_session_store.dart';

/// Plays one chunk or a queue of chunks of a sleep session back to back and
/// publishes the audible moment of the night as [playhead].
class SleepPlayer extends ChangeNotifier {
  SleepPlayer({this._resolveAudio}) {
    loadSettings();
  }
  final Future<File?> Function(SleepSession, SleepEvent)? _resolveAudio;
  static const _logPrefix = '[SleepPlayer]';
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
  bool _gainTouched = false;
  double _playingPeak = 1;
  bool _disposed = false;
  bool _cloudUnavailable = false;
  File? _playingFile;
  AudioSource? _source;
  SoundHandle? _handle;
  StreamSubscription<dynamic>? _soundEventsSub;
  Timer? _ticker;
  List<(Duration, Duration)> _audibleRanges = const [];
  int _generation = 0;
  final ValueNotifier<DateTime?> _playhead = ValueNotifier(null);
  final ScreenOnRequest _screenOn = ScreenOnRequest();

  ValueListenable<DateTime?> get playhead => _playhead;
  String? get sessionId => _session?.id;
  bool get paused => _paused;
  double get speed => _speed;
  bool get skipQuiet => _skipQuiet;
  double get gain => _gain;
  int get queueLength => _queue.length;
  int get queuePosition => _queuePos;
  File? get playingFile => _playingFile;

  /// The last chunk asked for lives on the server and could not be fetched.
  bool get cloudUnavailable => _cloudUnavailable;

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
    if (_disposed || _gainTouched) return;
    _gain = gain;
    _applyGain();
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
    _cloudUnavailable = false;
  }

  Future<File?> _resolve(SleepSession session, SleepEvent event) async {
    final resolve = _resolveAudio;
    if (resolve != null) return resolve(session, event);
    final file = session.data.fileFor(event);
    return session.hasFile(event) && await file.exists() ? file : null;
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
    _playingFile = null;
    final index = _queue[pos];
    final event = session.data.events[index];
    onChunkStarted?.call(session.id, index);
    notifyListeners();

    final file = await _resolve(session, event);
    if (_disposed || gen != _generation) return;
    if (file == null) {
      // A failed fetch would fail again for the next chunk, so stop instead
      // of waiting out one timeout per chunk.
      if (session.isOffloaded(event)) {
        _cloudUnavailable = true;
        await stop();
        return;
      }
      await (_continuous ? _startAt(pos + 1) : stop());
      return;
    }
    _playingFile = file;
    notifyListeners();
    try {
      if (!SoLoud.instance.isInitialized) await SoLoud.instance.init();
      final source = await SoLoud.instance.loadFile(file.path);
      if (gen != _generation) {
        unawaited(SoLoud.instance.disposeSource(source));
        return;
      }
      final handle = SoLoud.instance.play(source, paused: true);
      SoLoud.instance.setRelativePlaySpeed(handle, _speed);
      final measuredPeak = event.analysis?.peakAmplitude ?? 0;
      _playingPeak = measuredPeak > 0
          ? measuredPeak
          : session.synthetic || event.classification == 'unknown'
          ? 1
          : event.peakAmplitude > 0
          ? event.peakAmplitude
          : 1;
      SoLoud.instance.setVolume(
        handle,
        safeSleepPlaybackGain(_gain, _playingPeak),
      );
      _audibleRanges = _skipQuiet
          ? sleepPlaybackRanges(event.analysis, event.duration)
          : const [];
      if (_audibleRanges.isNotEmpty &&
          _audibleRanges.first.$1 > Duration.zero) {
        SoLoud.instance.seek(handle, _audibleRanges.first.$1);
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
      if (_playingPeak == 1 && _gain > 1) {
        unawaited(_measurePeak(file.path, gen));
      }
    } catch (e) {
      errorLog('$_logPrefix play ${event.fileName}: $e');
      await stop();
    }
  }

  Future<void> _measurePeak(String path, int gen) async {
    try {
      final peak = await compute(sleepPlaybackPeak, path);
      if (!_disposed && gen == _generation) {
        _playingPeak = peak;
        _applyGain();
      }
    } catch (e) {
      errorLog('$_logPrefix peak scan $path: $e');
    }
  }

  void _tick(int gen, SleepEvent event) {
    final handle = _handle;
    if (gen != _generation || handle == null) return;
    if (!SoLoud.instance.getIsValidVoiceHandle(handle)) return;
    final pos = SoLoud.instance.getPosition(handle);
    _playhead.value = event.startedAt.add(pos);
    if (!_paused && _audibleRanges.isNotEmpty) {
      final next = nextSleepPlaybackPosition(_audibleRanges, pos);
      if (next == null) {
        unawaited(_advance());
      } else if (next > pos) {
        SoLoud.instance.seek(handle, next);
      }
    }
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
    final handle = _handle;
    final session = _session;
    if (handle != null &&
        session != null &&
        SoLoud.instance.getIsValidVoiceHandle(handle)) {
      final event = session.data.events[_queue[_queuePos]];
      _audibleRanges = value
          ? sleepPlaybackRanges(event.analysis, event.duration)
          : const [];
      _tick(_generation, event);
    }
    notifyListeners();
  }

  void setGain(double value) {
    if (!playbackGains.contains(value)) return;
    _gainTouched = true;
    _gain = value;
    final file = _playingFile;
    if (value > 1 && _playingPeak == 1 && file != null && _handle != null) {
      unawaited(_measurePeak(file.path, _generation));
    }
    _applyGain();
    unawaited(
      DatabaseService.instance.setSetting(
        SoundFinderTool.config.id,
        _kPlaybackGain,
        value.toString(),
      ),
    );
    notifyListeners();
  }

  void _applyGain() {
    final handle = _handle;
    if (handle != null && SoLoud.instance.getIsValidVoiceHandle(handle)) {
      SoLoud.instance.setVolume(
        handle,
        safeSleepPlaybackGain(_gain, _playingPeak),
      );
    }
  }

  Future<void> stop() async {
    _generation++;
    await _releaseVoice();
    _session = null;
    _playingFile = null;
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
    _audibleRanges = const [];
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
  void notifyListeners() {
    _screenOn.set(_session != null && !_paused);
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _screenOn.set(false);
    _generation++;
    onChunkStarted = null;
    unawaited(_releaseVoice());
    _playhead.dispose();
    super.dispose();
  }
}
