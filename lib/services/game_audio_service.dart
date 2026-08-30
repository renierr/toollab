import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'package:tool_lab/helpers/debug_log.dart';

/// Plays a game's synthesized sound effects through SoLoud.
///
/// Clips are registered once by key (see [register]) and then fired by key,
/// so the per-hit path never touches WAV generation or disk. Every SoLoud call
/// is guarded: a machine with no audio device — a headless CI box, a Linux VM
/// without PulseAudio — must leave the game fully playable and silent rather
/// than throwing on the first hit.
///
/// SoLoud drops a play once its voice budget is gone, returning a handle that
/// addresses nothing rather than throwing. [_voiceCeiling] lifts that budget
/// past anything a board asks for.
///
/// Each game keeps its own instance (see `RicochetAudioService`,
/// `Twenty48AudioService`) rather than sharing one SoLoud voice pool, so one
/// game's loop or clip cache never bleeds into another's.
class GameAudioService {
  /// Prefixes every log line, so a failure names the game that caused it.
  final String logTag;

  GameAudioService(this.logTag);

  /// Frames per mix. SoLoud's default 2048 is ~46ms at 44.1kHz — longer than a
  /// 45ms impact tick, so every clip fired inside one window starts at the same
  /// sample offset. Near-identical ticks clumped like that merge into one sound
  /// to the ear, and a clip fired on a keypress waits up to a full buffer to be
  /// heard. 512 frames is ~12ms: short enough that neither shows.
  static const int _bufferFrames = 2048;

  /// Concurrent voices asked of SoLoud, well above what any board generates.
  /// The engine's own hard maximum is 1023.
  static const int _voiceCeiling = 64;

  final Map<String, AudioSource> _clips = {};

  /// Last play time per throttle group.
  final Map<String, int> _lastPlayMs = {};

  Future<void>? _initFuture;
  bool _available = false;
  double _masterVolume = 0.7;

  /// Whether sound actually reaches a device. False until [init] succeeds, and
  /// permanently false when the platform has no working audio backend.
  bool get isAvailable => _available;

  /// Idempotent, and safe to call from several games at once — the first call
  /// owns the initialization and the rest await the same future.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(
          bufferSize: _bufferFrames,
          lowLatency: false,
        );
      }
      _raiseVoiceCeiling();
      _available = true;
    } catch (e) {
      errorLog('[$logTag] Audio unavailable, running silent: $e');
      _available = false;
    }
  }

  /// The default 16 is nowhere near a board that can land a dozen impacts in
  /// one frame, and overflowing it drops sounds silently. Above the ceiling
  /// SoLoud keeps the loudest voices rather than refusing new ones, so the
  /// failure mode past this is graceful instead of arbitrary.
  void _raiseVoiceCeiling() {
    try {
      SoLoud.instance.setMaxActiveVoiceCount(_voiceCeiling);
    } catch (_) {}
  }

  String? _currentLoopKey;
  double _currentLoopVolume = 0.10;
  SoundHandle? _loopHandle;

  /// Volume every clip is scaled by, 0..1.
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    if (_loopHandle != null) {
      if (_masterVolume <= 0) {
        try {
          SoLoud.instance.stop(_loopHandle!);
        } catch (_) {}
        _loopHandle = null;
      } else {
        try {
          SoLoud.instance.setVolume(
            _loopHandle!,
            (_currentLoopVolume * _masterVolume).clamp(0.0, 1.0),
          );
        } catch (_) {}
      }
    } else if (_masterVolume > 0 && _currentLoopKey != null) {
      playLoop(_currentLoopKey!, volume: _currentLoopVolume);
    }
  }

  /// Loads one clip under [key], reusing cached [AudioSource] if already loaded.
  Future<void> register(String key, Uint8List wav) async {
    await init();
    if (!_available || _clips.containsKey(key)) return;
    try {
      _clips[key] = await SoLoud.instance.loadMem('ga_$key.wav', wav);
    } catch (e) {
      errorLog('[$logTag] Failed to register clip "$key": $e');
    }
  }

  Future<void> registerAll(Map<String, Uint8List> clips) async {
    for (final entry in clips.entries) {
      await register(entry.key, entry.value);
    }
    if (_available) _raiseVoiceCeiling();
  }

  /// Fires a registered clip.
  void play(
    String key, {
    double volume = 1.0,
    int minGapMs = 0,
    String? group,
  }) {
    if (!_available || _masterVolume <= 0) return;
    final source = _clips[key];
    if (source == null) return;

    final bucket = group ?? key;

    if (minGapMs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = _lastPlayMs[bucket];
      if (last != null && now - last < minGapMs) return;
      _lastPlayMs[bucket] = now;
    }

    try {
      SoLoud.instance.play(
        source,
        volume: (volume * _masterVolume).clamp(0.0, 1.0),
      );
    } catch (e) {
      debugLog('[$logTag] play("$key") failed: $e');
    }
  }

  /// Starts a continuous looping background track scaled by master volume.
  void playLoop(String key, {double volume = 0.10}) {
    _currentLoopKey = key;
    _currentLoopVolume = volume;
    if (!_available || _masterVolume <= 0) return;
    final source = _clips[key];
    if (source == null) return;
    try {
      if (_loopHandle != null) {
        SoLoud.instance.stop(_loopHandle!);
      }
      _loopHandle = SoLoud.instance.play(
        source,
        volume: (volume * _masterVolume).clamp(0.0, 1.0),
        looping: true,
      );
    } catch (_) {}
  }

  /// Stops the active background loop.
  void stopLoop() {
    _currentLoopKey = null;
    if (_loopHandle != null) {
      try {
        SoLoud.instance.stop(_loopHandle!);
      } catch (_) {}
      _loopHandle = null;
    }
  }

  /// Clears throttle timestamps. Clip sources are kept in memory for instant reuse.
  Future<void> releaseAll() async {
    _lastPlayMs.clear();
  }

  /// Fully releases audio resources when needed.
  Future<void> disposeAll() async {
    stopLoop();
    for (final source in _clips.values) {
      try {
        SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }
    _clips.clear();
    _lastPlayMs.clear();
  }
}
