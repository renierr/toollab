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

  /// Renders [seconds] of [type] noise as a loop-ready WAV off the UI thread.
  static Future<Uint8List> buildWav({
    required GeneratedNoiseType type,
    int seconds = 30,
    double fadeSeconds = 0.15,
  }) {
    return compute(_build, <String, dynamic>{
      'type': type.index,
      'seconds': seconds,
      'fade': fadeSeconds,
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

  for (int i = 0; i < fadeFrames; i++) {
    final double w = i / fadeFrames;
    for (int c = 0; c < channels; c++) {
      final int head = i * channels + c;
      final int tail = (loopFrames + i) * channels + c;
      gen[head] = gen[head] * w + gen[tail] * (1 - w);
    }
  }

  return WavPcm16Encoder.encode(
    gen,
    frames: loopFrames,
    sampleRate: rate,
    channels: channels,
  );
}
