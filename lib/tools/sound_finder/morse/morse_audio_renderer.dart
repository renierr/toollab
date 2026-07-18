import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../../helpers/wav_pcm16_encoder.dart';
import 'morse_converter.dart';

class MorseAudioRenderer {
  MorseAudioRenderer._();

  static const int sampleRate = 48000;

  /// Synthesizes Morse tokens into WAV bytes on a background isolate.
  static Future<Uint8List> render({
    required List<MorseToken> tokens,
    required double wpm,
    required double frequency,
  }) {
    return compute(_renderIsolate, <String, dynamic>{
      'tokens': tokens
          .map(
            (t) => {
              'char': t.char,
              'morse': t.morse,
              'isWordGap': t.isWordGap,
              'isCharGap': t.isCharGap,
            },
          )
          .toList(),
      'wpm': wpm,
      'frequency': frequency,
    });
  }
}

Uint8List _renderIsolate(Map<String, dynamic> args) {
  final List<dynamic> tokenData = args['tokens'] as List<dynamic>;
  final double wpm = args['wpm'] as double;
  final double freq = args['frequency'] as double;

  final List<MorseToken> tokens = tokenData
      .map(
        (t) => MorseToken(
          char: t['char'] as String,
          morse: t['morse'] as String,
          isWordGap: t['isWordGap'] as bool,
          isCharGap: t['isCharGap'] as bool,
        ),
      )
      .toList();

  final double unitSec = 1.2 / wpm;
  final int unitSamples = (unitSec * MorseAudioRenderer.sampleRate).round();

  // 1. Calculate total samples required
  int totalSamples = 0;
  for (final token in tokens) {
    if (token.isWordGap) {
      totalSamples += 7 * unitSamples;
    } else if (token.isCharGap) {
      totalSamples += 3 * unitSamples;
    } else {
      final code = token.morse;
      for (int i = 0; i < code.length; i++) {
        final sym = code[i];
        totalSamples += (sym == '-' ? 3 : 1) * unitSamples;
        if (i < code.length - 1) {
          totalSamples += 1 * unitSamples; // inter-element gap
        }
      }
    }
  }

  // Padding at the end
  totalSamples += 2 * unitSamples;

  final Float32List buffer = Float32List(totalSamples);
  int offset = 0;

  // 2. Synthesize audio with click-free envelopes
  const double twoPi = 2 * math.pi;
  final double step = twoPi * freq / MorseAudioRenderer.sampleRate;

  // 5ms attack/decay envelope to avoid speaker pops
  final int fadeSamplesLimit = (0.005 * MorseAudioRenderer.sampleRate).round();

  for (final token in tokens) {
    if (token.isWordGap) {
      offset += 7 * unitSamples;
    } else if (token.isCharGap) {
      offset += 3 * unitSamples;
    } else {
      final code = token.morse;
      for (int i = 0; i < code.length; i++) {
        final sym = code[i];
        final int durationSamples = (sym == '-' ? 3 : 1) * unitSamples;
        final int fade = math.min(fadeSamplesLimit, durationSamples ~/ 2);

        double phase = 0;
        for (int s = 0; s < durationSamples; s++) {
          final double waveVal = math.sin(phase);
          double envelope = 0.9; // 0.9 peak volume to avoid clipping

          if (s < fade) {
            envelope *= s / fade;
          } else if (s > durationSamples - fade) {
            envelope *= (durationSamples - s) / fade;
          }

          buffer[offset + s] = waveVal * envelope;
          phase += step;
          if (phase > twoPi) phase -= twoPi;
        }

        offset += durationSamples;
        if (i < code.length - 1) {
          offset += 1 * unitSamples; // inter-element silence
        }
      }
    }
  }

  return WavPcm16Encoder.encode(
    buffer,
    frames: totalSamples,
    sampleRate: MorseAudioRenderer.sampleRate,
    channels: 1,
  );
}
