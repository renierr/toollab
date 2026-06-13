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
  static const int _pushRounds = 24;
  static const int _initialRounds = 96;
  static const Duration _pushInterval = Duration(seconds: 2);

  final NoisePcmGenerator _generator = NoisePcmGenerator(
    sampleRate: _sampleRate,
    channels: _channels,
  );

  SoundHandle? _handle;
  AudioSource? _stream;
  AudioSource? _assetSource;
  Timer? _feedTimer;
  bool _pushing = false;
  bool _isPlaying = false;
  double _volume = 0.65;
  FocusNoiseSound? _currentSound;
  WakeLockLease? _partialWakeLock;
  ForegroundRuntimeLease? _foregroundRuntimeLease;

  int _totalPushedFrames = 0;
  int _startedAt = 0;

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
    _startedAt = 0;
    _totalPushedFrames = 0;
    _stream = SoLoud.instance.setBufferStream(
      sampleRate: _sampleRate,
      channels: Channels.stereo,
      format: BufferType.f32le,
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0,
      maxBufferSizeDuration: const Duration(seconds: 16),
    );

    _push(type, _initialRounds);
    _handle = SoLoud.instance.play(_stream!, volume: _volume);
    _isPlaying = true;
    _startedAt = DateTime.now().microsecondsSinceEpoch;

    _schedulePush(type);
  }

  void _schedulePush(GeneratedNoiseType type) {
    _feedTimer = Timer(_pushInterval, () => _onTimer(type));
  }

  void _onTimer(GeneratedNoiseType type) {
    if (_pushing || _stream == null) return;
    _pushing = true;
    try {
      _push(type, _pushRounds);
    } on SoLoudStreamEndedAlreadyCppException {
      _isPlaying = false;
      _feedTimer = null;
    } catch (e) {
      debugPrint('[FocusNoisePlayer] Push failed: $e');
    } finally {
      _pushing = false;
    }
    if (_isPlaying) {
      _schedulePush(type);
    }
  }

  int _estimatedBufferedFrames() {
    if (_startedAt == 0) return 0;
    final int elapsed = DateTime.now().microsecondsSinceEpoch - _startedAt;
    final int consumed = (elapsed * _sampleRate ~/ 1000000);
    return (_totalPushedFrames - consumed).clamp(0, _totalPushedFrames);
  }

  void _push(GeneratedNoiseType type, int rounds) {
    if (_stream == null) return;
    if (_estimatedBufferedFrames() >= 12 * _sampleRate) return;
    final int totalFrames = rounds * _chunkFrames;
    _totalPushedFrames += totalFrames;
    final Float32List buffer = Float32List(totalFrames * _channels);
    int offset = 0;
    for (int i = 0; i < rounds; i++) {
      final Float32List chunk = _generator.generate(
        type: type,
        frames: _chunkFrames,
      );
      buffer.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    SoLoud.instance.addAudioDataStream(_stream!, buffer.buffer.asUint8List());
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
