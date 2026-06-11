import 'dart:math';

import 'generated_sound_renderer.dart';

class WhiteNoiseRenderer implements GeneratedSoundRenderer {
  final Random _random;

  WhiteNoiseRenderer(this._random);

  @override
  void reset() {}

  @override
  StereoSample nextStereo() {
    return (_white(), _white());
  }

  double _white() => _random.nextDouble() * 2 - 1;
}
