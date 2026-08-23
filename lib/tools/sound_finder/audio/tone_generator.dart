import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../services/foreground_runtime_service.dart';
import '../../../services/media_controls_service.dart';
import '../../../services/power_wake_lock_service.dart';
import 'tone_loop_builder.dart';
import 'tone_waveform.dart';

export 'tone_waveform.dart';

/// Continuous, click-free waveform synthesizer.
///
/// A seamlessly-looping base tone is pre-rendered once and looped on the native
/// audio thread ([SoLoud.setLooping]). Frequency is tuned live by resampling
/// the loop via [SoLoud.setRelativePlaySpeed] (`speed = hz / baseFrequency`),
/// so sweeping stays smooth with no Dart timer feeding a buffer stream — which
/// removes the background-throttling underruns/overflows the old stream had.
/// Waveform and phase changes rebuild the (small) loop; volume and an optional
/// masking-noise mix are applied live on the playing handles.
class ToneGenerator {
  static const Duration _rebuildDebounce = Duration(milliseconds: 80);
  static const double _minSpeed = 0.05; // SoLoud's silent lower clamp
  static const double _maxSpeed = 256;

  SoundHandle? _toneHandle;
  AudioSource? _toneSource;
  SoundHandle? _noiseHandle;
  AudioSource? _noiseSource;

  Timer? _rebuildTimer;
  bool _isPlaying = false;

  /// Guards against a late-arriving async build overwriting a newer request.
  int _generation = 0;

  double _frequency = 440;
  ToneWaveform _waveform = ToneWaveform.sine;
  double _volume = 0.4;
  double _phaseOffset = 0; // radians, baked into the loop for counter tones
  double _noiseMix = 0; // 0..1 blend of white noise for masking

  WakeLockLease? _wakeLock;
  ForegroundRuntimeLease? _fgLease;

  String notificationTitle = 'Tone active';
  String notificationText = 'ToolLab is generating a tone';

  /// Invoked when playback is stopped from outside the app (the notification's
  /// stop action), so the owning state can sync its UI flags.
  VoidCallback? onExternalStop;
  StreamSubscription<MediaButton>? _mediaButtonSub;

  void _initMediaControls() {
    _mediaButtonSub ??= MediaControlsService.instance.buttonEvents.listen((
      button,
    ) {
      if (button == MediaButton.stop || button == MediaButton.pause) {
        unawaited(stop());
        onExternalStop?.call();
      }
    });
  }

  void _updateMediaControls(String title, MediaPlaybackStatus status) {
    _initMediaControls();
    unawaited(
      MediaControlsService.instance.updateMetadata(
        MediaMetadata(
          title: title,
          supportedButtons: const [
            MediaButton.play,
            MediaButton.pause,
            MediaButton.stop,
          ],
        ),
      ),
    );
    unawaited(MediaControlsService.instance.updatePlaybackStatus(status));
  }

  bool get isPlaying => _isPlaying;
  double get frequency => _frequency;
  ToneWaveform get waveform => _waveform;
  double get volume => _volume;
  double get phaseOffset => _phaseOffset;
  double get noiseMix => _noiseMix;

  double get _toneVolume => _volume * (1 - _noiseMix);
  double get _noiseVolume => _volume * _noiseMix;

  double _speedFor(double hz) =>
      (hz / ToneLoopBuilder.baseFrequency).clamp(_minSpeed, _maxSpeed);

  Future<void> start() async {
    await _ensureInit();
    if (_isPlaying) return;
    await _acquireLocks();
    _isPlaying = true;

    final int generation = ++_generation;
    await _spawnTone(generation);
    if (_noiseMix > 0) await _spawnNoise(generation);

    _updateMediaControls(
      '${_frequency.round()} Hz ${_waveform.name}',
      MediaPlaybackStatus.playing,
    );
  }

  Future<void> _spawnTone(int generation) async {
    final Uint8List wav = await ToneLoopBuilder.buildTone(
      waveform: _waveform,
      phaseOffset: _phaseOffset,
    );
    // Unique name per build: an identical name collides on SoLoud's sound hash
    // (fileAlreadyLoaded), which would let disposing the old loop tear down the
    // new one during a same-waveform rebuild.
    final AudioSource source = await SoLoud.instance.loadMem(
      'sf_tone_${_waveform.name}_$generation.wav',
      wav,
    );
    if (generation != _generation || !_isPlaying) {
      SoLoud.instance.disposeSource(source);
      return;
    }
    final SoundHandle handle = SoLoud.instance.play(
      source,
      volume: _toneVolume,
    );
    SoLoud.instance.setLooping(handle, true);
    SoLoud.instance.setRelativePlaySpeed(handle, _speedFor(_frequency));
    _toneSource = source;
    _toneHandle = handle;
  }

  Future<void> _spawnNoise(int generation) async {
    if (_noiseSource != null) return;
    final Uint8List wav = await ToneLoopBuilder.buildNoise();
    final AudioSource source = await SoLoud.instance.loadMem(
      'sf_noise_$generation.wav',
      wav,
    );
    if (generation != _generation || !_isPlaying) {
      SoLoud.instance.disposeSource(source);
      return;
    }
    final SoundHandle handle = SoLoud.instance.play(
      source,
      volume: _noiseVolume,
    );
    SoLoud.instance.setLooping(handle, true);
    _noiseSource = source;
    _noiseHandle = handle;
  }

  /// Rebuilds the tone loop after a waveform or phase change while playing.
  /// Debounced so dragging the phase slider does not thrash the isolate.
  void _scheduleRebuild() {
    if (!_isPlaying) return;
    _rebuildTimer?.cancel();
    _rebuildTimer = Timer(_rebuildDebounce, () {
      final int generation = ++_generation;
      final SoundHandle? oldHandle = _toneHandle;
      final AudioSource? oldSource = _toneSource;
      _toneHandle = null;
      _toneSource = null;
      unawaited(
        _spawnTone(generation).whenComplete(() {
          if (oldHandle != null) {
            unawaited(SoLoud.instance.stop(oldHandle).catchError((_) {}));
          }
          if (oldSource != null) {
            try {
              SoLoud.instance.disposeSource(oldSource);
            } catch (_) {}
          }
        }),
      );
    });
  }

  void setFrequency(double hz) {
    _frequency = hz.clamp(20, 20000);
    final SoundHandle? handle = _toneHandle;
    if (handle != null) {
      SoLoud.instance.setRelativePlaySpeed(handle, _speedFor(_frequency));
    }
  }

  void setWaveform(ToneWaveform w) {
    if (_waveform == w) return;
    _waveform = w;
    _scheduleRebuild();
  }

  void setPhaseOffset(double radians) {
    if (_phaseOffset == radians) return;
    _phaseOffset = radians;
    _scheduleRebuild();
  }

  void setNoiseMix(double value) {
    _noiseMix = value.clamp(0.0, 1.0);
    _applyVolumes();
    if (_isPlaying && _noiseMix > 0 && _noiseSource == null) {
      unawaited(_spawnNoise(_generation));
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    _applyVolumes();
  }

  void _applyVolumes() {
    final SoundHandle? tone = _toneHandle;
    if (tone != null) SoLoud.instance.setVolume(tone, _toneVolume);
    final SoundHandle? noise = _noiseHandle;
    if (noise != null) SoLoud.instance.setVolume(noise, _noiseVolume);
  }

  Future<void> stop() async {
    _isPlaying = false;
    _generation++;
    _rebuildTimer?.cancel();
    _rebuildTimer = null;

    await _stopSource(_toneHandle, _toneSource);
    _toneHandle = null;
    _toneSource = null;
    await _stopSource(_noiseHandle, _noiseSource);
    _noiseHandle = null;
    _noiseSource = null;

    _releaseLocks();
    unawaited(MediaControlsService.instance.clear());
  }

  Future<void> _stopSource(SoundHandle? handle, AudioSource? source) async {
    if (handle != null) {
      await SoLoud.instance.stop(handle);
    }
    if (source != null) {
      SoLoud.instance.disposeSource(source);
    }
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
        // Media treatment without a seek bar: the shade lists it as active
        // audio playback.
        media: MediaNotificationData(
          title: notificationTitle,
          positionMs: 0,
          playing: true,
        ),
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
    _mediaButtonSub?.cancel();
    _mediaButtonSub = null;
  }
}
