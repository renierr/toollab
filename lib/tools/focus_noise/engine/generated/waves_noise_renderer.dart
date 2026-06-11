import 'dart:math';

import 'generated_sound_renderer.dart';

class WavesNoiseRenderer implements GeneratedSoundRenderer {
  final int sampleRate;
  final Random random;

  double _baseLpL = 0;
  double _baseLpR = 0;
  double _foamLpL = 0;
  double _foamLpR = 0;
  double _lfoPhase = 0;

  WavesNoiseRenderer({required this.sampleRate, required this.random});

  @override
  void reset() {
    _baseLpL = 0;
    _baseLpR = 0;
    _foamLpL = 0;
    _foamLpR = 0;
    _lfoPhase = 0;
  }

  @override
  StereoSample nextStereo() {
    _lfoPhase += 2 * pi * 0.035 / sampleRate;
    if (_lfoPhase > 2 * pi) {
      _lfoPhase -= 2 * pi;
    }
    final double swell = 0.35 + 0.65 * (sin(_lfoPhase) + 1.0) * 0.5;

    final double baseAlpha = _alphaForCutoff(230);
    final double foamAlpha = _alphaForCutoff(2200);

    final double baseInL = _white() * 0.5;
    final double baseInR = _white() * 0.5;
    _baseLpL = _onePole(_baseLpL, baseInL, baseAlpha);
    _baseLpR = _onePole(_baseLpR, baseInR, baseAlpha);

    final double foamInL = _white() * 0.36;
    final double foamInR = _white() * 0.36;
    _foamLpL = _onePole(_foamLpL, foamInL, foamAlpha);
    _foamLpR = _onePole(_foamLpR, foamInR, foamAlpha);

    final double left = (_baseLpL * 0.85 + _foamLpL * swell * 0.55).clamp(
      -1.0,
      1.0,
    );
    final double right = (_baseLpR * 0.85 + _foamLpR * swell * 0.55).clamp(
      -1.0,
      1.0,
    );

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
