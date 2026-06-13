import 'dart:math';

import 'generated_sound_renderer.dart';

class GreenNoiseRenderer implements GeneratedSoundRenderer {
  final Random _random;
  final int sampleRate;

  double _lpL = 0;
  double _bpL = 0;
  double _lpR = 0;
  double _bpR = 0;

  GreenNoiseRenderer(this._random, {this.sampleRate = 48000});

  @override
  void reset() {
    _lpL = 0;
    _bpL = 0;
    _lpR = 0;
    _bpR = 0;
  }

  @override
  StereoSample nextStereo() {
    final double wL = _random.nextDouble() * 2 - 1;
    final double wR = _random.nextDouble() * 2 - 1;

    final double f = 2 * sin(pi * 500 / sampleRate);
    final double q = 0.7;

    final double hpInL = wL - _lpL - q * _bpL;
    _bpL = _bpL + f * hpInL;
    _lpL = _lpL + f * _bpL;

    final double hpInR = wR - _lpR - q * _bpR;
    _bpR = _bpR + f * hpInR;
    _lpR = _lpR + f * _bpR;

    final double gain = 2.2;
    return ((_bpL * gain).clamp(-1.0, 1.0), (_bpR * gain).clamp(-1.0, 1.0));
  }
}
