import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'mixer.dart';
import 'module.dart';

enum ChiptunePlaybackState { stopped, playing, paused }

/// Current pattern-order position and row within the playing module.
class SongPosition {
  final int order;
  final int row;
  const SongPosition(this.order, this.row);

  @override
  bool operator ==(Object other) =>
      other is SongPosition && other.order == order && other.row == row;

  @override
  int get hashCode => Object.hash(order, row);
}

/// Drives the software [ChiptuneMixer] and streams its PCM output to SoLoud.
///
/// The mixer renders interleaved stereo float32 which is pushed into a SoLoud
/// buffer stream. A periodic feed loop keeps a small look-ahead buffer filled
/// so playback stays smooth without large latency.
class ChiptunePlayer {
  static const int sampleRate = 44100;
  static const String _logPrefix = '[ChiptunePlayer]';

  // Look-ahead buffer target (~150ms) keeps row/LED callbacks close to audio.
  static const double _bufferAheadSeconds = 0.15;
  static const int _chunkFrames = 2048;

  final ChiptuneMixer _mixer = ChiptuneMixer();

  AudioSource? _stream;
  SoundHandle? _handle;
  Timer? _feedTimer;
  final Float32List _chunk = Float32List(_chunkFrames * 2);

  ModuleFile? _module;
  WorkletModule? _worklet;
  bool _ended = false;
  double _volume = 0.7;
  bool _looping = false;

  // Reactive outputs for the UI.
  final ValueNotifier<ChiptunePlaybackState> state = ValueNotifier(
    ChiptunePlaybackState.stopped,
  );
  final ValueNotifier<SongPosition> position = ValueNotifier(
    const SongPosition(0, 0),
  );
  final ValueNotifier<List<bool>> channelActivity = ValueNotifier(const []);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// Fired once when a non-looping song reaches its end.
  VoidCallback? onEnded;

  ModuleFile? get module => _module;
  bool get isPlaying => state.value == ChiptunePlaybackState.playing;
  bool get hasModule => _worklet != null;

  ChiptunePlayer() {
    _mixer.onRow = (order, row, active, _) {
      position.value = SongPosition(order, row);
      channelActivity.value = List<bool>.from(active);
    };
    _mixer.onEnded = () => _ended = true;
  }

  /// Total rows across the whole order list (for seek slider math).
  int get totalRows {
    final mod = _module;
    if (mod == null) return 1;
    int total = 0;
    for (final patIdx in mod.sequence) {
      if (patIdx >= 0 && patIdx < mod.patterns.length) {
        total += mod.patterns[patIdx].rows.length;
      }
    }
    return total > 0 ? total : 1;
  }

  /// Loads a parsed module but does not start playback.
  void loadModule(ModuleFile mod) {
    _stopInternal();
    _module = mod;
    _worklet = serializeModuleForWorklet(mod);
    channelActivity.value = List<bool>.filled(mod.channels, false);
    position.value = const SongPosition(0, 0);
    elapsed.value = Duration.zero;
  }

  Future<void> play() async {
    if (_worklet == null) return;

    if (state.value == ChiptunePlaybackState.paused && _handle != null) {
      SoLoud.instance.setPause(_handle!, false);
      state.value = ChiptunePlaybackState.playing;
      _startFeed();
      return;
    }

    await _ensureInit();
    _stopInternal();

    _ended = false;
    _mixer.loadAndPlay(_worklet!, sampleRate, looping: _looping);
    _mixer.setMasterVolume(_volume);

    _stream = SoLoud.instance.setBufferStream(
      sampleRate: sampleRate,
      channels: Channels.stereo,
      format: BufferType.f32le,
      bufferingType: BufferingType.released,
      maxBufferSizeDuration: const Duration(seconds: 10),
    );

    // Pre-fill before starting so playback begins instantly.
    _feed();
    _handle = SoLoud.instance.play(_stream!, volume: 1);
    state.value = ChiptunePlaybackState.playing;
    _startFeed();
  }

  void pause() {
    if (state.value != ChiptunePlaybackState.playing || _handle == null) return;
    SoLoud.instance.setPause(_handle!, true);
    _feedTimer?.cancel();
    _feedTimer = null;
    state.value = ChiptunePlaybackState.paused;
  }

  void stop() {
    _stopInternal();
    state.value = ChiptunePlaybackState.stopped;
    position.value = const SongPosition(0, 0);
    elapsed.value = Duration.zero;
    final mod = _module;
    if (mod != null) {
      channelActivity.value = List<bool>.filled(mod.channels, false);
    }
  }

  /// Seeks to an order/row and keeps playing if currently active.
  void seek(int order, int row) {
    if (_worklet == null) return;
    final wasPlaying = state.value == ChiptunePlaybackState.playing;
    _mixer.seek(order, row);
    if (_stream != null) {
      SoLoud.instance.resetBufferStream(_stream!);
    }
    if (wasPlaying) _feed();
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _mixer.setMasterVolume(_volume);
  }

  void setSpeed(int speed) => _mixer.setSpeed(speed);

  void setLooping(bool looping) {
    _looping = looping;
    _mixer.setLooping(looping);
  }

  void _startFeed() {
    _feedTimer?.cancel();
    _feedTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _feed(),
    );
  }

  void _feed() {
    final stream = _stream;
    if (stream == null) return;

    if (_handle != null) {
      elapsed.value = SoLoud.instance.getStreamTimeConsumed(stream);
    }

    if (_ended) {
      _onSongEnded();
      return;
    }

    final targetBytes = (sampleRate * _bufferAheadSeconds * 2 * 4)
        .toInt(); // stereo f32
    int guard = 0;
    while (!_ended && guard < 8) {
      int buffered;
      try {
        buffered = SoLoud.instance.getBufferSize(stream);
      } catch (_) {
        buffered = targetBytes; // stop topping up if query fails
      }
      if (buffered >= targetBytes) break;

      _mixer.render(_chunk, _chunkFrames);
      try {
        SoLoud.instance.addAudioDataStream(stream, _chunk.buffer.asUint8List());
      } catch (e) {
        debugPrint('$_logPrefix addAudioDataStream failed: $e');
        break;
      }
      guard++;
    }
  }

  void _onSongEnded() {
    _feedTimer?.cancel();
    _feedTimer = null;
    if (_stream != null) {
      SoLoud.instance.setDataIsEnded(_stream!);
    }
    state.value = ChiptunePlaybackState.stopped;
    onEnded?.call();
  }

  Future<void> _ensureInit() async {
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
  }

  void _stopInternal() {
    _feedTimer?.cancel();
    _feedTimer = null;
    _mixer.stop();
    final handle = _handle;
    if (handle != null) {
      SoLoud.instance.stop(handle);
      _handle = null;
    }
    final stream = _stream;
    if (stream != null) {
      SoLoud.instance.disposeSource(stream);
      _stream = null;
    }
  }

  void dispose() {
    _stopInternal();
    state.dispose();
    position.dispose();
    channelActivity.dispose();
    elapsed.dispose();
  }
}
