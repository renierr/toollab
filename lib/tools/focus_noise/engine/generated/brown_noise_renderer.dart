import 'dart:math';

import 'generated_sound_renderer.dart';

class BrownNoiseRenderer implements GeneratedSoundRenderer {
  final Random _random;

  double _left = 0;
  double _right = 0;

  BrownNoiseRenderer(this._random);

  @override
  void reset() {
    _left = 0;
    _right = 0;
  }

  @override
  StereoSample nextStereo() {
    return (_brownLeft(), _brownRight());
  }

  double _white() => _random.nextDouble() * 2 - 1;

  double _brownLeft() {
    final double white = _white();
    _left = (_left + 0.02 * white) / 1.02;
    return (_left * 3.5).clamp(-1.0, 1.0);
  }

  double _brownRight() {
    final double white = _white();
    _right = (_right + 0.02 * white) / 1.02;
    return (_right * 3.5).clamp(-1.0, 1.0);
  }
}
