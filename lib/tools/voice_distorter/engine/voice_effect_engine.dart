import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../helpers/debug_log.dart';
import '../../../services/database_service.dart';
import 'voice_effect.dart';
import 'voice_recorder.dart';
import 'wav_utils.dart';

/// Loads a recorded clip once and re-applies the six [VoiceEffectParams] knobs
/// as per-source SoLoud filters on every play — no reload needed to switch
/// presets. Filter parameters can only be set on a live [SoundHandle], so
/// [play] starts paused, writes the values, then unpauses to avoid an audible
/// jump at the start of playback.
class VoiceEffectEngine {
  VoiceEffectEngine._();

  static final VoiceEffectEngine instance = VoiceEffectEngine._();

  static const int _renderSampleRate = 44100;
  static const int _renderChannels = 2;

  AudioSource? _source;
  SoundHandle? _handle;
  StreamSubscription<StreamSoundEvent>? _endSub;
  bool _stereoClip = false;

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

  /// [isStereo] must only be true when the file is known to have two channels:
  /// the reverb filter aborts natively on anything else. Returns false when the
  /// clip could not be decoded.
  Future<bool> loadClip(String path, {required bool isStereo}) async {
    await _ensureInit();
    await stop();
    final AudioSource? old = _source;
    _source = null;
    // Must complete before reloading: a re-record reuses the same path, and
    // SoLoud would otherwise hand back the source it is still disposing.
    if (old != null) await SoLoud.instance.disposeSource(old);
    _stereoClip = isStereo;
    try {
      _source = await SoLoud.instance.loadFile(path);
      return true;
    } catch (e) {
      errorLog('[VoiceEffectEngine] loading clip failed: $e');
      return false;
    }
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

    await _endSub?.cancel();
    _endSub = source.soundEvents.listen((event) {
      if (event.handle == handle &&
          event.event == SoundEventType.handleIsNoMoreValid) {
        _handle = null;
        isPlaying.value = false;
      }
    });
  }

  /// Plays the clip once with [params] while capturing the mixer output, and
  /// returns it as WAV bytes. SoLoud has no offline render, so this runs in
  /// real time and is audible — a 10 s clip takes 10 s.
  Future<Uint8List?> renderToWav(VoiceEffectParams params) async {
    final AudioSource? source = _source;
    if (source == null) return null;
    await stop();

    final chunks = <Uint8List>[];
    final ended = Completer<void>();
    StreamSubscription<Uint8List>? captureSub;
    StreamSubscription<StreamSoundEvent>? endSub;
    try {
      // Mixer capture is the only way to get the filtered signal back out.
      // ignore: experimental_member_use
      final Stream<Uint8List> capture = SoLoud.instance.startMixerOutputStream(
        format: MixerOutputFormat.pcmS16le,
        sampleRate: _renderSampleRate,
        channels: _renderChannels,
        chunkPCMFrames: 2048,
      );
      captureSub = capture.listen(chunks.add);

      final SoundHandle handle = SoLoud.instance.play(source, paused: true);
      _applyFilters(source, handle, params);
      endSub = source.soundEvents.listen((event) {
        if (event.handle == handle &&
            event.event == SoundEventType.handleIsNoMoreValid &&
            !ended.isCompleted) {
          ended.complete();
        }
      });
      SoLoud.instance.setPause(handle, false);

      await ended.future.timeout(
        const Duration(seconds: VoiceRecorder.maxSeconds + 5),
        onTimeout: () => SoLoud.instance.stop(handle),
      );
      // Let the last mixer buffers reach the capture stream.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      errorLog('[VoiceEffectEngine] render failed: $e');
      return null;
    } finally {
      await endSub?.cancel();
      // ignore: experimental_member_use
      SoLoud.instance.stopMixerOutputStream();
      await captureSub?.cancel();
    }

    if (chunks.isEmpty) return null;
    final pcm = Uint8List(chunks.fold(0, (sum, c) => sum + c.length));
    int offset = 0;
    for (final chunk in chunks) {
      pcm.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return buildPcmWav(
      pcm: pcm,
      sampleRate: _renderSampleRate,
      channels: _renderChannels,
      bitsPerSample: 16,
    );
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
      _stereoClip && p.reverbAmount > 0.01,
      () => filters.freeverbFilter.activate(),
      () => filters.freeverbFilter.deactivate(),
      () {
        // Freeverb scales its wet signal by 3 and the dry by 2, so a raw 1.0
        // wet is a loud, washed-out mess. Keep the mix in a musical range.
        filters.freeverbFilter.wet(soundHandle: handle).value =
            p.reverbAmount * 0.45;
        filters.freeverbFilter.roomSize(soundHandle: handle).value = 0.6;
        filters.freeverbFilter.damp(soundHandle: handle).value = 0.4;
        filters.freeverbFilter.width(soundHandle: handle).value = 1;
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
            22050 - p.lofiAmount * 14000;
        filters.lofiFilter.bitdepth(soundHandle: handle).value =
            12 - p.lofiAmount * 6;
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
        // The curve barely bends below ~0.3, so map the knob onto the useful
        // part of the range instead of a fixed amount.
        filters.waveShaperFilter.amount(soundHandle: handle).value =
            0.3 + p.distortionAmount * 0.65;
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
    _stereoClip = false;
    if (source != null) await SoLoud.instance.disposeSource(source);
  }
}
