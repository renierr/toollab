import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../services/foreground_runtime_service.dart';
import '../../../services/power_wake_lock_service.dart';

enum ToneWaveform { sine, square, triangle, sawtooth }

/// Continuous, click-free waveform synthesizer built on SoLoud's buffer stream.
/// Frequency, waveform, phase offset and noise mix are read live per chunk, so
/// they can be tuned while playing without restarting the stream.
class ToneGenerator {
  static const int _sampleRate = 48000;
  static const int _chunkFrames = 4096;
  static const int _initialRounds = 8;
  static const int _pushRounds = 4;
  static const Duration _pushInterval = Duration(milliseconds: 200);

  SoundHandle? _handle;
  AudioSource? _stream;
  Timer? _feedTimer;
  bool _pushing = false;
  bool _isPlaying = false;

  double _frequency = 440;
  ToneWaveform _waveform = ToneWaveform.sine;
  double _volume = 0.4;
  double _phaseOffset = 0; // radians, used for phase-inverted counter tones
  double _noiseMix = 0; // 0..1 blend of white noise for masking

  double _phase = 0; // running phase accumulator
  int _totalPushedFrames = 0;
  int _startedAt = 0;
  final math.Random _rng = math.Random();

  WakeLockLease? _wakeLock;
  ForegroundRuntimeLease? _fgLease;

  String notificationTitle = 'Tone active';
  String notificationText = 'ToolLab is generating a tone';

  /// Invoked when playback is stopped from outside the app (the notification's
  /// stop action), so the owning state can sync its UI flags.
  VoidCallback? onExternalStop;

  bool get isPlaying => _isPlaying;
  double get frequency => _frequency;
  ToneWaveform get waveform => _waveform;
  double get volume => _volume;
  double get phaseOffset => _phaseOffset;
  double get noiseMix => _noiseMix;

  Future<void> start() async {
    await _ensureInit();
    if (_isPlaying) return;
    await _acquireLocks();

    _phase = 0;
    _totalPushedFrames = 0;
    _startedAt = 0;
    _stream = SoLoud.instance.setBufferStream(
      sampleRate: _sampleRate,
      channels: Channels.mono,
      format: BufferType.f32le,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0,
      maxBufferSizeDuration: const Duration(seconds: 4),
    );

    _push(_initialRounds);
    _handle = SoLoud.instance.play(_stream!, volume: _volume);
    _isPlaying = true;
    _startedAt = DateTime.now().microsecondsSinceEpoch;
    _schedule();
  }

  void _schedule() {
    _feedTimer = Timer(_pushInterval, _onTimer);
  }

  void _onTimer() {
    if (_pushing || _stream == null) return;
    _pushing = true;
    try {
      _push(_pushRounds);
    } on SoLoudStreamEndedAlreadyCppException {
      _isPlaying = false;
      _feedTimer = null;
    } catch (e) {
      debugPrint('[ToneGenerator] push failed: $e');
    } finally {
      _pushing = false;
    }
    if (_isPlaying) _schedule();
  }

  int _estimatedBufferedFrames() {
    if (_startedAt == 0) return 0;
    final int elapsed = DateTime.now().microsecondsSinceEpoch - _startedAt;
    final int consumed = elapsed * _sampleRate ~/ 1000000;
    return (_totalPushedFrames - consumed).clamp(0, _totalPushedFrames);
  }

  void _push(int rounds) {
    final AudioSource? stream = _stream;
    if (stream == null) return;
    if (_estimatedBufferedFrames() >= 2 * _sampleRate) return;

    final int total = rounds * _chunkFrames;
    _totalPushedFrames += total;
    final buffer = Float32List(total);
    const double twoPi = 2 * math.pi;
    final double step = twoPi * _frequency / _sampleRate;

    for (int i = 0; i < total; i++) {
      final double ph = _phase + _phaseOffset;
      double v = switch (_waveform) {
        ToneWaveform.sine => math.sin(ph),
        ToneWaveform.square => math.sin(ph) >= 0 ? 1.0 : -1.0,
        ToneWaveform.triangle => 2 / math.pi * math.asin(math.sin(ph)),
        ToneWaveform.sawtooth =>
          2 * (ph / twoPi - (ph / twoPi + 0.5).floorToDouble()),
      };
      if (_noiseMix > 0) {
        final double noise = _rng.nextDouble() * 2 - 1;
        v = v * (1 - _noiseMix) + noise * _noiseMix;
      }
      buffer[i] = v * 0.9; // headroom to avoid clipping
      _phase += step;
      if (_phase > twoPi) _phase -= twoPi;
    }

    SoLoud.instance.addAudioDataStream(stream, buffer.buffer.asUint8List());
  }

  void setFrequency(double hz) => _frequency = hz.clamp(20, 20000);
  void setWaveform(ToneWaveform w) => _waveform = w;
  void setPhaseOffset(double radians) => _phaseOffset = radians;
  void setNoiseMix(double value) => _noiseMix = value.clamp(0.0, 1.0);

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    final SoundHandle? handle = _handle;
    if (handle != null) SoLoud.instance.setVolume(handle, _volume);
  }

  Future<void> stop() async {
    _isPlaying = false;
    _feedTimer?.cancel();
    _feedTimer = null;
    _pushing = false;

    final SoundHandle? handle = _handle;
    if (handle != null) {
      await SoLoud.instance.stop(handle);
      _handle = null;
    }
    final AudioSource? stream = _stream;
    if (stream != null) {
      SoLoud.instance.disposeSource(stream);
      _stream = null;
    }
    _releaseLocks();
  }

  Future<void> _ensureInit() async {
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
  }

  Future<void> _acquireLocks() async {
    _wakeLock ??= await PowerWakeLockService.acquirePartial();
    if (_fgLease == null) {
      _fgLease = await ForegroundRuntimeService.acquire(
        title: notificationTitle,
        text: notificationText,
        actions: const ['stop'],
      );
      ForegroundRuntimeService.addActionListener(_handleNotificationAction);
    }
  }

  void _releaseLocks() {
    if (_fgLease != null) {
      ForegroundRuntimeService.removeActionListener(_handleNotificationAction);
      final ForegroundRuntimeLease? lease = _fgLease;
      _fgLease = null;
      if (lease != null) unawaited(lease.release());
    }
    final WakeLockLease? wakeLock = _wakeLock;
    _wakeLock = null;
    if (wakeLock != null) unawaited(wakeLock.release());
  }

  void _handleNotificationAction(String action) {
    if (action == 'stop') {
      unawaited(stop());
      onExternalStop?.call();
    }
  }

  Future<void> dispose() async {
    await stop();
  }
}
