import 'dart:math';

import 'generated_sound_renderer.dart';

class TrainNoiseRenderer implements GeneratedSoundRenderer {
  final int sampleRate;
  final Random _random;

  int _t = 0;

  double _brownL = 0, _brownR = 0;
  double _rumbleLpL = 0, _rumbleLpR = 0;

  double _pB0L = 0, _pB1L = 0, _pB2L = 0;
  double _pB3L = 0, _pB4L = 0, _pB5L = 0, _pB6L = 0;
  double _pB0R = 0, _pB1R = 0, _pB2R = 0;
  double _pB3R = 0, _pB4R = 0, _pB5R = 0, _pB6R = 0;

  double _svLpL = 0, _svBpL = 0;
  double _svLpR = 0, _svBpR = 0;

  int _nextClack = 0;
  int _clackStart = -1;

  TrainNoiseRenderer({required this.sampleRate, required this._random});

  @override
  void reset() {
    _t = 0;
    _brownL = 0;
    _brownR = 0;
    _rumbleLpL = 0;
    _rumbleLpR = 0;
    _pB0L = 0;
    _pB1L = 0;
    _pB2L = 0;
    _pB3L = 0;
    _pB4L = 0;
    _pB5L = 0;
    _pB6L = 0;
    _pB0R = 0;
    _pB1R = 0;
    _pB2R = 0;
    _pB3R = 0;
    _pB4R = 0;
    _pB5R = 0;
    _pB6R = 0;
    _svLpL = 0;
    _svBpL = 0;
    _svLpR = 0;
    _svBpR = 0;
    _nextClack = 0;
    _clackStart = -1;
  }

  @override
  StereoSample nextStereo() {
    final double rA = _ac(150);
    final double lfo = 1.0 + 0.3 * sin(_t * 2 * pi * 100 / sampleRate);
    final double rA2 = (rA * lfo).clamp(0.0001, 0.95);

    _brownL = _brown(_brownL);
    _brownR = _brown(_brownR);
    _rumbleLpL = _op(_rumbleLpL, _brownL, rA2);
    _rumbleLpR = _op(_rumbleLpR, _brownR, rA2);

    double outL = _rumbleLpL * 0.3;
    double outR = _rumbleLpR * 0.3;

    final double pL = _pinkL();
    final double pR = _pinkR();
    final double lfoW = 1.0 + 0.07 * sin(_t * 2 * pi * 0.04 / sampleRate);
    final double wF = (800.0 * lfoW).clamp(20, sampleRate * 0.45);
    final double svF = 2 * sin(pi * wF / sampleRate);
    final double svQ = 0.4;
    final double lfoG = 1.0 + 0.1 * sin(_t * 2 * pi * 0.04 / sampleRate + 1.0);
    final double bpL = _svfBp(pL, svF, svQ, isL: true);
    final double bpR = _svfBp(pR, svF, svQ, isL: false);
    outL += bpL * 0.05 * lfoG;
    outR += bpR * 0.05 * lfoG;

    if (_t >= _nextClack) {
      _clackStart = _nextClack;
      final double jitter = (_random.nextDouble() - 0.5) * 0.28;
      _nextClack = _t + ((1.6 + jitter) * sampleRate).round();
    }

    if (_clackStart >= 0) {
      final double dt = (_t - _clackStart) / sampleRate;
      outL += _pulse(dt, 0.00, 350, 0.10);
      outR += _pulse(dt, 0.18, 400, 0.07);
      outL += _pulse(dt, 0.45, 300, 0.08);
      outR += _pulse(dt, 0.63, 380, 0.06);
      if (dt > 0.85) _clackStart = -1;
    }

    _t++;
    return (outL.clamp(-1.0, 1.0), outR.clamp(-1.0, 1.0));
  }

  double _pulse(double dt, double off, double freq, double vol) {
    final double t = dt - off;
    if (t < 0 || t > 0.25) return 0;
    double env;
    if (t < 0.003) {
      env = t / 0.003;
    } else if (t < 0.04) {
      env = 1.0 - (t - 0.003) / 0.037 * 0.6;
    } else {
      env = 0.4 * exp(-(t - 0.04) * 30);
    }
    final double thump = sin(2 * pi * (t * freq % 1.0));
    final double rattle = (_random.nextDouble() * 2 - 1);
    return (thump * 0.3 + rattle * 0.7) * env * vol;
  }

  double _svfBp(double input, double f, double q, {required bool isL}) {
    if (isL) {
      final double hp = input - _svLpL - q * _svBpL;
      _svBpL = _svBpL + f * hp;
      _svLpL = _svLpL + f * _svBpL;
      return _svBpL;
    } else {
      final double hp = input - _svLpR - q * _svBpR;
      _svBpR = _svBpR + f * hp;
      _svLpR = _svLpR + f * _svBpR;
      return _svBpR;
    }
  }

  double _brown(double state) {
    final double w = _random.nextDouble() * 2 - 1;
    return (state + w * 0.02).clamp(-1.0, 1.0);
  }

  double _pinkL() {
    final double w = _random.nextDouble() * 2 - 1;
    _pB0L = 0.99886 * _pB0L + w * 0.0555179;
    _pB1L = 0.99332 * _pB1L + w * 0.0750759;
    _pB2L = 0.96900 * _pB2L + w * 0.1538520;
    _pB3L = 0.86650 * _pB3L + w * 0.3104856;
    _pB4L = 0.55000 * _pB4L + w * 0.5329522;
    _pB5L = -0.7616 * _pB5L - w * 0.0168980;
    final double v =
        (_pB0L + _pB1L + _pB2L + _pB3L + _pB4L + _pB5L + _pB6L + w * 0.5362) *
        0.11;
    _pB6L = w * 0.115926;
    return v.clamp(-1.0, 1.0);
  }

  double _pinkR() {
    final double w = _random.nextDouble() * 2 - 1;
    _pB0R = 0.99886 * _pB0R + w * 0.0555179;
    _pB1R = 0.99332 * _pB1R + w * 0.0750759;
    _pB2R = 0.96900 * _pB2R + w * 0.1538520;
    _pB3R = 0.86650 * _pB3R + w * 0.3104856;
    _pB4R = 0.55000 * _pB4R + w * 0.5329522;
    _pB5R = -0.7616 * _pB5R - w * 0.0168980;
    final double v =
        (_pB0R + _pB1R + _pB2R + _pB3R + _pB4R + _pB5R + _pB6R + w * 0.5362) *
        0.11;
    _pB6R = w * 0.115926;
    return v.clamp(-1.0, 1.0);
  }

  double _ac(double hz) => (2 * pi * hz / sampleRate).clamp(0.0001, 0.95);

  double _op(double s, double i, double a) => s + a * (i - s);
}
