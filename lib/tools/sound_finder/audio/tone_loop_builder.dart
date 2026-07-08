import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../helpers/wav_pcm16_encoder.dart';
import 'tone_waveform.dart';

/// Pre-renders seamlessly-looping WAV buffers for the tone generator.
///
/// The tone is rendered once at a fixed [baseFrequency] holding a whole number
/// of cycles, so it loops on the native audio thread ([SoLoud.setLooping])
/// without a seam click. Playback then shifts pitch live via relative play
/// speed (`speed = targetHz / baseFrequency`) — no Dart timer feeds any buffer,
/// so background throttling can no longer starve/overflow the stream.
class ToneLoopBuilder {
  ToneLoopBuilder._();

  static const int sampleRate = 48000;

  /// Loop length in frames. A low nominal base with this length keeps a dense
  /// source (many samples per cycle) so pitching the loop up to ~20 kHz stays
  /// clean, while the 0.05 play-speed floor still reaches below 20 Hz.
  static const int loopFrames = 9600;
  static const double _nominalBase = 110;

  static const double _headroom = 0.9; // avoid clipping

  static int get _cycles => (_nominalBase * loopFrames / sampleRate).round();

  /// The exact frequency the base loop was rendered at. Slightly rounded from
  /// [_nominalBase] so the loop holds an integer cycle count. Playback divides
  /// the target frequency by this to get the relative play speed.
  static double get baseFrequency => _cycles * sampleRate / loopFrames;

  /// Renders one loop of [waveform] (with optional [phaseOffset] radians baked
  /// in for phase-inverted counter tones) off the UI thread.
  static Future<Uint8List> buildTone({
    required ToneWaveform waveform,
    double phaseOffset = 0,
  }) {
    return compute(_buildTone, <String, dynamic>{
      'waveform': waveform.index,
      'phase': phaseOffset,
    });
  }

  /// Renders a white-noise loop (mono) with a crossfaded seam so the random
  /// signal does not click each time it wraps. Played un-pitched (speed 1.0)
  /// and mixed under the tone for masking.
  static Future<Uint8List> buildNoise({
    int seconds = 2,
    double fadeSeconds = 0.15,
  }) {
    return compute(_buildNoise, <String, dynamic>{
      'seconds': seconds,
      'fade': fadeSeconds,
    });
  }
}

Uint8List _buildTone(Map<String, dynamic> args) {
  final ToneWaveform waveform = ToneWaveform.values[args['waveform'] as int];
  final double phaseOffset = args['phase'] as double;

  const int frames = ToneLoopBuilder.loopFrames;
  const int rate = ToneLoopBuilder.sampleRate;
  const double twoPi = 2 * math.pi;
  final double step = twoPi * ToneLoopBuilder.baseFrequency / rate;

  final Float32List out = Float32List(frames);
  double phase = phaseOffset;
  for (int i = 0; i < frames; i++) {
    final double v = switch (waveform) {
      ToneWaveform.sine => math.sin(phase),
      ToneWaveform.square => math.sin(phase) >= 0 ? 1.0 : -1.0,
      ToneWaveform.triangle => 2 / math.pi * math.asin(math.sin(phase)),
      ToneWaveform.sawtooth =>
        2 * (phase / twoPi - (phase / twoPi + 0.5).floorToDouble()),
    };
    out[i] = v * ToneLoopBuilder._headroom;
    phase += step;
    if (phase > twoPi) phase -= twoPi;
  }

  return WavPcm16Encoder.encode(
    out,
    frames: frames,
    sampleRate: rate,
    channels: 1,
  );
}

Uint8List _buildNoise(Map<String, dynamic> args) {
  final int seconds = args['seconds'] as int;
  final double fadeSeconds = args['fade'] as double;

  const int rate = ToneLoopBuilder.sampleRate;
  final int loopFrames = seconds * rate;
  final int fadeFrames = (fadeSeconds * rate).round();
  final int totalFrames = loopFrames + fadeFrames;

  final math.Random rng = math.Random(1234);
  final Float32List gen = Float32List(totalFrames);
  for (int i = 0; i < totalFrames; i++) {
    gen[i] = (rng.nextDouble() * 2 - 1) * ToneLoopBuilder._headroom;
  }

  // Fold the extra tail back over the start so the wrap crossfades.
  for (int i = 0; i < fadeFrames; i++) {
    final double w = i / fadeFrames;
    gen[i] = gen[i] * w + gen[loopFrames + i] * (1 - w);
  }

  return WavPcm16Encoder.encode(
    gen,
    frames: loopFrames,
    sampleRate: rate,
    channels: 1,
  );
}
