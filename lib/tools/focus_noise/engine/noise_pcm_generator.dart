import 'dart:math';
import 'dart:typed_data';

import 'generated/brown_noise_renderer.dart';
import 'generated/generated_sound_renderer.dart';
import 'generated/green_noise_renderer.dart';
import 'generated/pink_noise_renderer.dart';
import 'generated/train_noise_renderer.dart';
import 'generated/white_noise_renderer.dart';

enum GeneratedNoiseType { white, pink, brown, train, green }

class NoisePcmGenerator {
  final int sampleRate;
  final int channels;
  final Random _random = Random();

  late final Map<GeneratedNoiseType, GeneratedSoundRenderer> _renderers;

  NoisePcmGenerator({this.sampleRate = 48000, this.channels = 2}) {
    _renderers = <GeneratedNoiseType, GeneratedSoundRenderer>{
      GeneratedNoiseType.white: WhiteNoiseRenderer(_random),
      GeneratedNoiseType.pink: PinkNoiseRenderer(_random),
      GeneratedNoiseType.brown: BrownNoiseRenderer(_random),
      GeneratedNoiseType.train: TrainNoiseRenderer(
        sampleRate: sampleRate,
        random: _random,
      ),
      GeneratedNoiseType.green: GreenNoiseRenderer(
        _random,
        sampleRate: sampleRate,
      ),
    };
  }

  void reset() {
    for (final GeneratedSoundRenderer renderer in _renderers.values) {
      renderer.reset();
    }
  }

  Float32List generate({
    required GeneratedNoiseType type,
    required int frames,
  }) {
    final Float32List data = Float32List(frames * channels);
    final GeneratedSoundRenderer renderer = _renderers[type]!;
    int out = 0;

    for (int i = 0; i < frames; i++) {
      final (double left, double right) = renderer.nextStereo();
      data[out++] = left;
      data[out++] = right;
    }

    return data;
  }
}
