import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../services/database_service.dart';
import 'voice_effect.dart';

/// Loads a recorded clip once and re-applies the six [VoiceEffectParams] knobs
/// as per-source SoLoud filters on every play — no reload needed to switch
/// presets. Filter parameters can only be set on a live [SoundHandle], so
/// [play] starts paused, writes the values, then unpauses to avoid an audible
/// jump at the start of playback.
class VoiceEffectEngine {
  VoiceEffectEngine._();

  static final VoiceEffectEngine instance = VoiceEffectEngine._();

  AudioSource? _source;
  SoundHandle? _handle;
  StreamSubscription<StreamSoundEvent>? _endSub;

  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  bool get hasClip => _source != null;

  Future<void> _ensureInit() async {
    if (!SoLoud.instance.isInitialized) {
      final lowLatencyVal = await DatabaseService.instance.getSetting(
        '_app',
        'low_latency_audio',
      );
      final lowLatency = lowLatencyVal != 'false';
      await SoLoud.instance.init(lowLatency: lowLatency);
    }
  }

  Future<void> loadClip(String path) async {
    await _ensureInit();
    await stop();
    final AudioSource? old = _source;
    _source = null;
    if (old != null) SoLoud.instance.disposeSource(old);
    _source = await SoLoud.instance.loadFile(path);
  }

  Future<void> play(VoiceEffectParams params) async {
    final AudioSource? source = _source;
    if (source == null) return;
    await stop();

    final SoundHandle handle = SoLoud.instance.play(source, paused: true);
    _applyFilters(source, handle, params);
    SoLoud.instance.setPause(handle, false);
    _handle = handle;
    isPlaying.value = true;

    _endSub?.cancel();
    _endSub = source.soundEvents.listen((event) {
      if (event.handle == handle &&
          event.event == SoundEventType.handleIsNoMoreValid) {
        _handle = null;
        isPlaying.value = false;
      }
    });
  }

  void _applyFilters(
    AudioSource source,
    SoundHandle handle,
    VoiceEffectParams p,
  ) {
    final filters = source.filters;

    _setFilter(
      filters.pitchShiftFilter.isActive,
      p.pitchSemitones.abs() > 0.01,
      () => filters.pitchShiftFilter.activate(),
      () => filters.pitchShiftFilter.deactivate(),
      () {
        filters.pitchShiftFilter.wet(soundHandle: handle).value = 1;
        filters.pitchShiftFilter.semitones(soundHandle: handle).value =
            p.pitchSemitones;
      },
    );

    _setFilter(
      filters.robotizeFilter.isActive,
      p.robotAmount > 0.01,
      () => filters.robotizeFilter.activate(),
      () => filters.robotizeFilter.deactivate(),
      () {
        filters.robotizeFilter.wet(soundHandle: handle).value = p.robotAmount;
        filters.robotizeFilter.frequency(soundHandle: handle).value =
            20 + p.robotAmount * 40;
      },
    );

    _setFilter(
      filters.echoFilter.isActive,
      p.echoAmount > 0.01,
      () => filters.echoFilter.activate(),
      () => filters.echoFilter.deactivate(),
      () {
        filters.echoFilter.wet(soundHandle: handle).value = p.echoAmount;
        filters.echoFilter.delay(soundHandle: handle).value = 0.18;
        filters.echoFilter.decay(soundHandle: handle).value = 0.55;
      },
    );

    _setFilter(
      filters.freeverbFilter.isActive,
      p.reverbAmount > 0.01,
      () => filters.freeverbFilter.activate(),
      () => filters.freeverbFilter.deactivate(),
      () {
        filters.freeverbFilter.wet(soundHandle: handle).value = p.reverbAmount;
        filters.freeverbFilter.roomSize(soundHandle: handle).value = 0.6;
        filters.freeverbFilter.damp(soundHandle: handle).value = 0.4;
      },
    );

    _setFilter(
      filters.lofiFilter.isActive,
      p.lofiAmount > 0.01,
      () => filters.lofiFilter.activate(),
      () => filters.lofiFilter.deactivate(),
      () {
        filters.lofiFilter.wet(soundHandle: handle).value = p.lofiAmount;
        filters.lofiFilter.samplerate(soundHandle: handle).value =
            8000 - p.lofiAmount * 6000;
        filters.lofiFilter.bitdepth(soundHandle: handle).value =
            8 - p.lofiAmount * 5;
      },
    );

    _setFilter(
      filters.waveShaperFilter.isActive,
      p.distortionAmount > 0.01,
      () => filters.waveShaperFilter.activate(),
      () => filters.waveShaperFilter.deactivate(),
      () {
        filters.waveShaperFilter.wet(soundHandle: handle).value =
            p.distortionAmount;
        filters.waveShaperFilter.amount(soundHandle: handle).value = 0.6;
      },
    );
  }

  void _setFilter(
    bool isActive,
    bool shouldBeActive,
    VoidCallback activate,
    VoidCallback deactivate,
    VoidCallback setParams,
  ) {
    if (shouldBeActive && !isActive) activate();
    if (!shouldBeActive && isActive) deactivate();
    if (shouldBeActive) setParams();
  }

  Future<void> stop() async {
    final SoundHandle? handle = _handle;
    _handle = null;
    await _endSub?.cancel();
    _endSub = null;
    if (handle != null) {
      await SoLoud.instance.stop(handle);
    }
    isPlaying.value = false;
  }

  Future<void> dispose() async {
    await stop();
    final AudioSource? source = _source;
    _source = null;
    if (source != null) SoLoud.instance.disposeSource(source);
  }
}
