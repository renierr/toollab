import 'dart:math';

import 'generated_sound_renderer.dart';

class RainNoiseRenderer implements GeneratedSoundRenderer {
  final int sampleRate;
  final Random random;

  double _bedLpL = 0;
  double _bedLpR = 0;
  double _dropEnvL = 0;
  double _dropEnvR = 0;

  RainNoiseRenderer({required this.sampleRate, required this.random});

  @override
  void reset() {
    _bedLpL = 0;
    _bedLpR = 0;
    _dropEnvL = 0;
    _dropEnvR = 0;
  }

  @override
  StereoSample nextStereo() {
    final double bedAlpha = _alphaForCutoff(1200);

    final double bedInL = _white() * 0.4;
    final double bedInR = _white() * 0.4;
    _bedLpL = _onePole(_bedLpL, bedInL, bedAlpha);
    _bedLpR = _onePole(_bedLpR, bedInR, bedAlpha);

    if (random.nextDouble() < 0.006) {
      _dropEnvL += random.nextDouble() * 0.35;
    }
    if (random.nextDouble() < 0.006) {
      _dropEnvR += random.nextDouble() * 0.35;
    }
    _dropEnvL *= 0.992;
    _dropEnvR *= 0.992;

    final double dropL = _white() * _dropEnvL;
    final double dropR = _white() * _dropEnvR;

    final double left = (_bedLpL * 0.72 + dropL * 0.7).clamp(-1.0, 1.0);
    final double right = (_bedLpR * 0.72 + dropR * 0.7).clamp(-1.0, 1.0);

    return (left, right);
  }

  double _white() => random.nextDouble() * 2 - 1;

  double _alphaForCutoff(double cutoffHz) {
    final double alpha = 2 * pi * cutoffHz / sampleRate;
    return alpha.clamp(0.0001, 0.95);
  }

  double _onePole(double state, double input, double alpha) {
    return state + alpha * (input - state);
  }
}
