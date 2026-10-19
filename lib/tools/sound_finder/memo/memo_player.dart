import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:tool_lab/helpers/debug_log.dart';

/// Plays one memo at a time. The playhead lives in [position] so only the
/// playing tile repaints on each tick.
class MemoPlayer extends ChangeNotifier {
  static const _logPrefix = '[MemoPlayer]';

  String? _path;
  AudioSource? _source;
  SoundHandle? _handle;
  StreamSubscription<StreamSoundEvent>? _endSub;
  Timer? _ticker;
  Duration _length = Duration.zero;
  bool _paused = false;
  double _speed = 1.0;
  int _generation = 0;
  bool _disposed = false;

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  String? get path => _path;
  bool get paused => _paused;
  double get speed => _speed;
  Duration get length => _length;

  bool isCurrent(String path) => _path == path;
  bool isPlaying(String path) => _path == path && !_paused;

  Future<void> toggle(String path, {Duration? from}) async {
    if (_path == path) {
      if (_paused) {
        resume();
      } else {
        pause();
      }
      return;
    }
    await play(path, from: from);
  }

  Future<void> play(String path, {Duration? from}) async {
    await stop();
    final generation = ++_generation;
    try {
      if (!SoLoud.instance.isInitialized) await SoLoud.instance.init();
      // Disk streaming keeps hour-long memos from being decoded into RAM.
      final source = await SoLoud.instance.loadFile(path, mode: LoadMode.disk);
      if (generation != _generation || _disposed) {
        await SoLoud.instance.disposeSource(source);
        return;
      }
      final handle = SoLoud.instance.play(source, paused: true);
      SoLoud.instance.setRelativePlaySpeed(handle, _speed);
      _source = source;
      _handle = handle;
      _path = path;
      _length = SoLoud.instance.getLength(source);
      if (from != null && from > Duration.zero && from < _length) {
        SoLoud.instance.seek(handle, from);
      }
      SoLoud.instance.setPause(handle, false);
      _paused = false;
      position.value = from ?? Duration.zero;
      _endSub = source.soundEvents.listen((event) {
        if (event.handle == handle &&
            event.event == SoundEventType.handleIsNoMoreValid) {
          unawaited(stop());
        }
      });
      _ticker = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _tick(),
      );
      _notify();
    } catch (e) {
      errorLog('$_logPrefix play failed: $e');
      await stop();
    }
  }

  void _tick() {
    final handle = _handle;
    if (handle == null || _paused) return;
    try {
      position.value = SoLoud.instance.getPosition(handle);
    } catch (_) {}
  }

  void pause() {
    final handle = _handle;
    if (handle == null || _paused) return;
    SoLoud.instance.setPause(handle, true);
    _paused = true;
    _tick();
    _notify();
  }

  void resume() {
    final handle = _handle;
    if (handle == null || !_paused) return;
    SoLoud.instance.setPause(handle, false);
    _paused = false;
    _notify();
  }

  void seek(Duration to) {
    final handle = _handle;
    if (handle == null) return;
    final clamped = to < Duration.zero
        ? Duration.zero
        : (to > _length ? _length : to);
    SoLoud.instance.seek(handle, clamped);
    position.value = clamped;
  }

  void skip(Duration delta) => seek(position.value + delta);

  void setSpeed(double speed) {
    _speed = speed;
    final handle = _handle;
    if (handle != null) SoLoud.instance.setRelativePlaySpeed(handle, speed);
    _notify();
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    await _endSub?.cancel();
    _endSub = null;
    final handle = _handle;
    final source = _source;
    _handle = null;
    _source = null;
    final hadPath = _path != null;
    _path = null;
    _paused = false;
    _length = Duration.zero;
    position.value = Duration.zero;
    try {
      if (handle != null) await SoLoud.instance.stop(handle);
      if (source != null) await SoLoud.instance.disposeSource(source);
    } catch (e) {
      errorLog('$_logPrefix stop failed: $e');
    }
    if (hadPath) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _ticker?.cancel();
    unawaited(_endSub?.cancel());
    final handle = _handle;
    final source = _source;
    _handle = null;
    _source = null;
    unawaited(() async {
      try {
        if (handle != null) await SoLoud.instance.stop(handle);
        if (source != null) await SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }());
    position.dispose();
    super.dispose();
  }
}
