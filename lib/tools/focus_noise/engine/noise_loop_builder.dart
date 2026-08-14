import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../helpers/wav_pcm16_encoder.dart';
import 'noise_pcm_generator.dart';

/// Pre-renders a seamlessly-looping 16-bit PCM WAV for a generated noise type.
///
/// Playback then hands the whole buffer to SoLoud and loops it on the native
/// audio thread ([SoLoud.setLooping]) — no Dart timer feeds the stream, so
/// background throttling can no longer cause underruns/stutter.
class NoiseLoopBuilder {
  NoiseLoopBuilder._();

  static const int sampleRate = 48000;
  static const int channels = 2;

  /// Seam crossfade length per type. The fade must be long compared to the
  /// slowest wave the noise carries, otherwise the wrap is heard as a texture
  /// change — brown/pink hold the most low-frequency energy and need the most.
  static double defaultFadeSeconds(GeneratedNoiseType type) {
    return switch (type) {
      GeneratedNoiseType.brown => 2.5,
      GeneratedNoiseType.pink => 1.5,
      GeneratedNoiseType.train => 1.0,
      GeneratedNoiseType.white || GeneratedNoiseType.green => 0.5,
    };
  }

  /// Renders [seconds] of [type] noise as a loop-ready WAV off the UI thread.
  static Future<Uint8List> buildWav({
    required GeneratedNoiseType type,
    int seconds = 30,
    double? fadeSeconds,
  }) {
    return compute(_build, <String, dynamic>{
      'type': type.index,
      'seconds': seconds,
      'fade': fadeSeconds ?? defaultFadeSeconds(type),
    });
  }
}

Uint8List _build(Map<String, dynamic> args) {
  final GeneratedNoiseType type =
      GeneratedNoiseType.values[args['type'] as int];
  final int seconds = args['seconds'] as int;
  final double fadeSeconds = args['fade'] as double;

  const int rate = NoiseLoopBuilder.sampleRate;
  const int channels = NoiseLoopBuilder.channels;

  final int loopFrames = seconds * rate;
  final int fadeFrames = (fadeSeconds * rate).round();
  final int totalFrames = loopFrames + fadeFrames;

  final NoisePcmGenerator generator = NoisePcmGenerator(
    sampleRate: rate,
    channels: channels,
  );
  generator.reset();
  // Extra `fadeFrames` continue naturally past the loop end; folding them back
  // into the start crossfades the seam so random-walk noise (brown/pink/train)
  // does not click each time it wraps.
  final Float32List gen = generator.generate(type: type, frames: totalFrames);

  // Equal-power (sin/cos) weights, not linear: the two halves are uncorrelated
  // noise, so linear weights lose ~3 dB mid-fade and the seam is heard as a dip.
  for (int i = 0; i < fadeFrames; i++) {
    final double t = i / fadeFrames * math.pi / 2;
    final double wHead = math.sin(t);
    final double wTail = math.cos(t);
    for (int c = 0; c < channels; c++) {
      final int head = i * channels + c;
      final int tail = (loopFrames + i) * channels + c;
      gen[head] = (gen[head] * wHead + gen[tail] * wTail).clamp(-1.0, 1.0);
    }
  }

  return WavPcm16Encoder.encode(
    gen,
    frames: loopFrames,
    sampleRate: rate,
    channels: channels,
  );
}
