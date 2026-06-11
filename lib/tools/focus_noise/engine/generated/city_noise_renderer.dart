import 'dart:math';

import 'generated_sound_renderer.dart';

class CityNoiseRenderer implements GeneratedSoundRenderer {
  final int sampleRate;
  final Random random;

  double _rumbleLpL = 0;
  double _rumbleLpR = 0;
  double _hissLpL = 0;
  double _hissLpR = 0;

  final List<_CityToneVoice> _horns = <_CityToneVoice>[
    _CityToneVoice(),
    _CityToneVoice(),
  ];
  final List<_CitySirenVoice> _sirens = <_CitySirenVoice>[_CitySirenVoice()];

  CityNoiseRenderer({required this.sampleRate, required this.random});

  @override
  void reset() {
    _rumbleLpL = 0;
    _rumbleLpR = 0;
    _hissLpL = 0;
    _hissLpR = 0;
    for (final _CityToneVoice horn in _horns) {
      horn.reset();
    }
    for (final _CitySirenVoice siren in _sirens) {
      siren.reset();
    }
  }

  @override
  StereoSample nextStereo() {
    final double rumbleAlpha = _alphaForCutoff(150);
    final double hissAlpha = _alphaForCutoff(1800);

    final double rumbleInL = _white() * 0.55;
    final double rumbleInR = _white() * 0.55;
    _rumbleLpL = _onePole(_rumbleLpL, rumbleInL, rumbleAlpha);
    _rumbleLpR = _onePole(_rumbleLpR, rumbleInR, rumbleAlpha);

    final double hissInL = _white() * 0.22;
    final double hissInR = _white() * 0.22;
    _hissLpL = _onePole(_hissLpL, hissInL, hissAlpha);
    _hissLpR = _onePole(_hissLpR, hissInR, hissAlpha);
    final double hissHpL = hissInL - _hissLpL;
    final double hissHpR = hissInR - _hissLpR;

    if (random.nextDouble() < 0.00004) {
      for (final _CityToneVoice horn in _horns) {
        if (!horn.active) {
          horn.start(sampleRate: sampleRate, random: random);
          break;
        }
      }
    }

    if (random.nextDouble() < 0.00001) {
      for (final _CitySirenVoice siren in _sirens) {
        if (!siren.active) {
          siren.start(sampleRate: sampleRate, random: random);
          break;
        }
      }
    }

    double toneL = 0;
    double toneR = 0;
    for (final _CityToneVoice horn in _horns) {
      final double sample = horn.nextSample(sampleRate: sampleRate);
      if (sample == 0) continue;
      toneL += sample * (1.0 - max(0.0, horn.pan));
      toneR += sample * (1.0 + min(0.0, horn.pan));
    }
    for (final _CitySirenVoice siren in _sirens) {
      final double sample = siren.nextSample(sampleRate: sampleRate);
      if (sample == 0) continue;
      toneL += sample * (1.0 - max(0.0, siren.pan));
      toneR += sample * (1.0 + min(0.0, siren.pan));
    }

    final double left = (_rumbleLpL * 0.85 + hissHpL * 0.35 + toneL * 0.9)
        .clamp(-1.0, 1.0);
    final double right = (_rumbleLpR * 0.85 + hissHpR * 0.35 + toneR * 0.9)
        .clamp(-1.0, 1.0);

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

class _CityToneVoice {
  bool active = false;
  int index = 0;
  int length = 0;
  double frequency = 0;
  double pan = 0;

  void reset() {
    active = false;
    index = 0;
  }

  void start({required int sampleRate, required Random random}) {
    active = true;
    index = 0;
    length = (sampleRate * (0.18 + random.nextDouble() * 0.55)).round();
    frequency = 260 + random.nextDouble() * 500;
    pan = random.nextDouble() * 1.6 - 0.8;
  }

  double nextSample({required int sampleRate}) {
    if (!active || index >= length) {
      active = false;
      return 0;
    }

    final double t = index / sampleRate;
    final double env = sin(pi * (index / length));
    index++;
    return sin(2 * pi * frequency * t) * env * env * 0.18;
  }
}

class _CitySirenVoice {
  bool active = false;
  int index = 0;
  int length = 0;
  double baseFreq = 0;
  double pan = 0;

  void reset() {
    active = false;
    index = 0;
  }

  void start({required int sampleRate, required Random random}) {
    active = true;
    index = 0;
    length = (sampleRate * (2.4 + random.nextDouble() * 2.8)).round();
    baseFreq = 380 + random.nextDouble() * 140;
    pan = random.nextDouble() * 1.2 - 0.6;
  }

  double nextSample({required int sampleRate}) {
    if (!active || index >= length) {
      active = false;
      return 0;
    }

    final double t = index / sampleRate;
    final double sweep = sin(2 * pi * 0.26 * t);
    final double freq = baseFreq + 170 * sweep;
    final double env = sin(pi * (index / length));
    index++;
    return sin(2 * pi * freq * t) * env * env * 0.15;
  }
}
