import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../services/foreground_runtime_service.dart';
import '../../../services/power_wake_lock_service.dart';
import '../focus_noise_sound.dart';
import 'noise_pcm_generator.dart';

class FocusNoisePlayer {
  static const int _sampleRate = 48000;
  static const int _channels = 2;
  static const int _chunkFrames = 4096;
  static const Duration _feedEvery = Duration(milliseconds: 24);
  static const int _targetBufferedBytes = _sampleRate * _channels * 4 * 4;

  final NoisePcmGenerator _generator = NoisePcmGenerator(
    sampleRate: _sampleRate,
    channels: _channels,
  );

  SoundHandle? _handle;
  AudioSource? _stream;
  AudioSource? _assetSource;
  Timer? _feedTimer;
  bool _feedBusy = false;
  bool _isPlaying = false;
  double _volume = 0.65;
  FocusNoiseSound? _currentSound;
  WakeLockLease? _partialWakeLock;
  ForegroundRuntimeLease? _foregroundRuntimeLease;

  bool get isPlaying => _isPlaying;
  double get volume => _volume;
  FocusNoiseSound? get currentSound => _currentSound;

  Future<void> play(FocusNoiseSound sound) async {
    await _ensureInit();
    await stop();

    _currentSound = sound;
    await _acquireLocks();

    if (sound.isAsset) {
      await _playAsset(sound);
      return;
    }

    await _playGenerated(sound);
  }

  Future<void> _playAsset(FocusNoiseSound sound) async {
    final String? assetPath = sound.assetPath;
    if (assetPath == null) return;
    _assetSource = await SoLoud.instance.loadAsset(assetPath);
    _handle = SoLoud.instance.play(_assetSource!, volume: _volume);
    SoLoud.instance.setLooping(_handle!, true);
    _isPlaying = true;
  }

  Future<void> _playGenerated(FocusNoiseSound sound) async {
    final GeneratedNoiseType type = switch (sound.id) {
      'white' => GeneratedNoiseType.white,
      'pink' => GeneratedNoiseType.pink,
      'brown' => GeneratedNoiseType.brown,
      'train' => GeneratedNoiseType.train,
      'green' => GeneratedNoiseType.green,
      _ => GeneratedNoiseType.pink,
    };

    _generator.reset();
    _stream = SoLoud.instance.setBufferStream(
      sampleRate: _sampleRate,
      channels: Channels.stereo,
      format: BufferType.f32le,
      bufferingType: BufferingType.released,
      maxBufferSizeDuration: const Duration(seconds: 16),
    );

    _pushGenerated(type, rounds: 48, fadeIn: true);
    _handle = SoLoud.instance.play(_stream!, volume: _volume);
    _isPlaying = true;

    _feedTimer = Timer.periodic(_feedEvery, (_) => _maintainBuffer(type));
  }

  void _maintainBuffer(GeneratedNoiseType type) {
    if (!_isPlaying || _stream == null || _feedBusy) return;
    _feedBusy = true;
    try {
      final int buffered = SoLoud.instance.getBufferSize(_stream!);
      if (buffered < _targetBufferedBytes) {
        _pushGenerated(type, rounds: 2);
      }
    } catch (e) {
      debugPrint('[FocusNoisePlayer] Buffer feed failed: $e');
    } finally {
      _feedBusy = false;
    }
  }

  void _pushGenerated(
    GeneratedNoiseType type, {
    required int rounds,
    bool fadeIn = false,
  }) {
    if (_stream == null) return;
    for (int i = 0; i < rounds; i++) {
      final Float32List chunk = _generator.generate(
        type: type,
        frames: _chunkFrames,
      );
      if (fadeIn && i == 0) {
        final int fadeFrames = 512;
        for (int j = 0; j < fadeFrames && j < _chunkFrames; j++) {
          final double gain = j / fadeFrames;
          chunk[j * 2] *= gain;
          chunk[j * 2 + 1] *= gain;
        }
      }
      SoLoud.instance.addAudioDataStream(_stream!, chunk.buffer.asUint8List());
    }
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);
    final handle = _handle;
    if (handle != null) {
      SoLoud.instance.setVolume(handle, _volume);
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    _feedTimer?.cancel();
    _feedTimer = null;

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

    final AudioSource? asset = _assetSource;
    if (asset != null) {
      SoLoud.instance.disposeSource(asset);
      _assetSource = null;
    }

    _releaseLocks();
  }

  Future<void> _ensureInit() async {
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
  }

  Future<void> _acquireLocks() async {
    _partialWakeLock ??= await PowerWakeLockService.acquirePartial();
    _foregroundRuntimeLease ??= await ForegroundRuntimeService.acquire(
      title: 'Focus noise active',
      text: 'ToolLab keeps ambient audio running',
    );
  }

  void _releaseLocks() {
    final WakeLockLease? wakeLock = _partialWakeLock;
    if (wakeLock != null) {
      unawaited(wakeLock.release());
    }
    _partialWakeLock = null;

    final ForegroundRuntimeLease? runtime = _foregroundRuntimeLease;
    if (runtime != null) {
      unawaited(runtime.release());
    }
    _foregroundRuntimeLease = null;
  }

  Future<void> dispose() async {
    await stop();
  }
}
