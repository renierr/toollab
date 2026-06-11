import 'dart:math';

import 'generated_sound_renderer.dart';

class PinkNoiseRenderer implements GeneratedSoundRenderer {
  final Random _random;

  double _b0L = 0;
  double _b1L = 0;
  double _b2L = 0;
  double _b3L = 0;
  double _b4L = 0;
  double _b5L = 0;
  double _b6L = 0;

  double _b0R = 0;
  double _b1R = 0;
  double _b2R = 0;
  double _b3R = 0;
  double _b4R = 0;
  double _b5R = 0;
  double _b6R = 0;

  PinkNoiseRenderer(this._random);

  @override
  void reset() {
    _b0L = 0;
    _b1L = 0;
    _b2L = 0;
    _b3L = 0;
    _b4L = 0;
    _b5L = 0;
    _b6L = 0;

    _b0R = 0;
    _b1R = 0;
    _b2R = 0;
    _b3R = 0;
    _b4R = 0;
    _b5R = 0;
    _b6R = 0;
  }

  @override
  StereoSample nextStereo() {
    return (_pinkLeft(), _pinkRight());
  }

  double _white() => _random.nextDouble() * 2 - 1;

  double _pinkLeft() {
    final double white = _white();
    _b0L = 0.99886 * _b0L + white * 0.0555179;
    _b1L = 0.99332 * _b1L + white * 0.0750759;
    _b2L = 0.96900 * _b2L + white * 0.1538520;
    _b3L = 0.86650 * _b3L + white * 0.3104856;
    _b4L = 0.55000 * _b4L + white * 0.5329522;
    _b5L = -0.7616 * _b5L - white * 0.0168980;
    final double value =
        (_b0L + _b1L + _b2L + _b3L + _b4L + _b5L + _b6L + white * 0.5362) *
        0.11;
    _b6L = white * 0.115926;
    return value.clamp(-1.0, 1.0);
  }

  double _pinkRight() {
    final double white = _white();
    _b0R = 0.99886 * _b0R + white * 0.0555179;
    _b1R = 0.99332 * _b1R + white * 0.0750759;
    _b2R = 0.96900 * _b2R + white * 0.1538520;
    _b3R = 0.86650 * _b3R + white * 0.3104856;
    _b4R = 0.55000 * _b4R + white * 0.5329522;
    _b5R = -0.7616 * _b5R - white * 0.0168980;
    final double value =
        (_b0R + _b1R + _b2R + _b3R + _b4R + _b5R + _b6R + white * 0.5362) *
        0.11;
    _b6R = white * 0.115926;
    return value.clamp(-1.0, 1.0);
  }
}
