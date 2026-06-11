import 'dart:math';

import 'generated_sound_renderer.dart';

class ForestNoiseRenderer implements GeneratedSoundRenderer {
  final int sampleRate;
  final Random random;

  double _windLpL = 0;
  double _windLpR = 0;
  double _leavesLpL = 0;
  double _leavesLpR = 0;
  double _leavesHpL = 0;
  double _leavesHpR = 0;
  double _lfoPhase = 0;

  final List<_ForestChirpVoice> _birds = <_ForestChirpVoice>[
    _ForestChirpVoice(),
    _ForestChirpVoice(),
    _ForestChirpVoice(),
  ];

  ForestNoiseRenderer({required this.sampleRate, required this.random});

  @override
  void reset() {
    _windLpL = 0;
    _windLpR = 0;
    _leavesLpL = 0;
    _leavesLpR = 0;
    _leavesHpL = 0;
    _leavesHpR = 0;
    _lfoPhase = 0;
    for (final _ForestChirpVoice voice in _birds) {
      voice.reset();
    }
  }

  @override
  StereoSample nextStereo() {
    _lfoPhase += 2 * pi * 0.08 / sampleRate;
    if (_lfoPhase > 2 * pi) {
      _lfoPhase -= 2 * pi;
    }

    final double windCutoff = 350 + 180 * (sin(_lfoPhase) + 1.0);
    final double windAlpha = _alphaForCutoff(windCutoff);
    final double leavesLpAlpha = _alphaForCutoff(3000);
    final double leavesHpAlpha = _alphaForCutoff(900);

    final double windInL = _white() * 0.45;
    final double windInR = _white() * 0.45;
    _windLpL = _onePole(_windLpL, windInL, windAlpha);
    _windLpR = _onePole(_windLpR, windInR, windAlpha);

    final double leavesRawL = _white() * 0.35;
    final double leavesRawR = _white() * 0.35;
    _leavesHpL = _onePole(_leavesHpL, leavesRawL, leavesHpAlpha);
    _leavesHpR = _onePole(_leavesHpR, leavesRawR, leavesHpAlpha);
    final double leavesBandL = leavesRawL - _leavesHpL;
    final double leavesBandR = leavesRawR - _leavesHpR;
    _leavesLpL = _onePole(_leavesLpL, leavesBandL, leavesLpAlpha);
    _leavesLpR = _onePole(_leavesLpR, leavesBandR, leavesLpAlpha);

    final (double birdsL, double birdsR) = _birdLayer();

    final double left = (_windLpL * 0.65 + _leavesLpL * 0.45 + birdsL * 0.55)
        .clamp(-1.0, 1.0);
    final double right = (_windLpR * 0.65 + _leavesLpR * 0.45 + birdsR * 0.55)
        .clamp(-1.0, 1.0);

    return (left, right);
  }

  (double, double) _birdLayer() {
    for (final _ForestChirpVoice voice in _birds) {
      if (!voice.active && random.nextDouble() < 0.00009) {
        voice.start(sampleRate: sampleRate, random: random);
      }
    }

    double left = 0;
    double right = 0;
    for (final _ForestChirpVoice voice in _birds) {
      final double sample = voice.nextSample(sampleRate: sampleRate);
      if (sample == 0) continue;
      left += sample * (1.0 - max(0.0, voice.pan));
      right += sample * (1.0 + min(0.0, voice.pan));
    }
    return (left.clamp(-1.0, 1.0), right.clamp(-1.0, 1.0));
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

class _ForestChirpVoice {
  bool active = false;
  int index = 0;
  int length = 0;
  double startFreq = 0;
  double endFreq = 0;
  double pan = 0;

  void reset() {
    active = false;
    index = 0;
  }

  void start({required int sampleRate, required Random random}) {
    active = true;
    index = 0;
    length = (sampleRate * (0.08 + random.nextDouble() * 0.22)).round();
    startFreq = 1800 + random.nextDouble() * 2200;
    endFreq = startFreq + 250 + random.nextDouble() * 1000;
    pan = random.nextDouble() * 1.4 - 0.7;
  }

  double nextSample({required int sampleRate}) {
    if (!active || index >= length) {
      active = false;
      return 0;
    }

    final double t = index / sampleRate;
    final double freq = startFreq + (endFreq - startFreq) * (index / length);
    final double env = sin(pi * (index / length));
    index++;
    return sin(2 * pi * freq * t) * env * env * 0.22;
  }
}
