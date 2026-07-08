import 'package:flutter/foundation.dart';

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

  return _encodeWav(gen, loopFrames, rate, channels);
}

Uint8List _encodeWav(Float32List samples, int frames, int rate, int channels) {
  const int bytesPerSample = 2;
  final int dataBytes = frames * channels * bytesPerSample;
  final int byteRate = rate * channels * bytesPerSample;
  final int blockAlign = channels * bytesPerSample;

  final ByteData bd = ByteData(44 + dataBytes);
  _writeAscii(bd, 0, 'RIFF');
  bd.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(bd, 8, 'WAVE');
  _writeAscii(bd, 12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, channels, Endian.little);
  bd.setUint32(24, rate, Endian.little);
  bd.setUint32(28, byteRate, Endian.little);
  bd.setUint16(32, blockAlign, Endian.little);
  bd.setUint16(34, bytesPerSample * 8, Endian.little);
  _writeAscii(bd, 36, 'data');
  bd.setUint32(40, dataBytes, Endian.little);

  int offset = 44;
  final int count = frames * channels;
  for (int i = 0; i < count; i++) {
    final double s = samples[i].clamp(-1.0, 1.0);
    bd.setInt16(offset, (s * 32767).round(), Endian.little);
    offset += bytesPerSample;
  }
  return bd.buffer.asUint8List();
}

void _writeAscii(ByteData bd, int offset, String text) {
  for (int i = 0; i < text.length; i++) {
    bd.setUint8(offset + i, text.codeUnitAt(i));
  }
}
