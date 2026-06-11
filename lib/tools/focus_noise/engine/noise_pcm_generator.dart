import 'dart:math';
import 'dart:typed_data';

enum GeneratedNoiseType { white, pink, brown }

class NoisePcmGenerator {
  final int sampleRate;
  final int channels;
  final Random _random = Random();

  double _brownLeft = 0;
  double _brownRight = 0;

  double _pinkB0L = 0;
  double _pinkB1L = 0;
  double _pinkB2L = 0;
  double _pinkB3L = 0;
  double _pinkB4L = 0;
  double _pinkB5L = 0;
  double _pinkB6L = 0;

  double _pinkB0R = 0;
  double _pinkB1R = 0;
  double _pinkB2R = 0;
  double _pinkB3R = 0;
  double _pinkB4R = 0;
  double _pinkB5R = 0;
  double _pinkB6R = 0;

  NoisePcmGenerator({this.sampleRate = 48000, this.channels = 2});

  void reset() {
    _brownLeft = 0;
    _brownRight = 0;
    _pinkB0L = 0;
    _pinkB1L = 0;
    _pinkB2L = 0;
    _pinkB3L = 0;
    _pinkB4L = 0;
    _pinkB5L = 0;
    _pinkB6L = 0;
    _pinkB0R = 0;
    _pinkB1R = 0;
    _pinkB2R = 0;
    _pinkB3R = 0;
    _pinkB4R = 0;
    _pinkB5R = 0;
    _pinkB6R = 0;
  }

  Float32List generate({
    required GeneratedNoiseType type,
    required int frames,
  }) {
    final Float32List data = Float32List(frames * channels);
    int out = 0;

    for (int i = 0; i < frames; i++) {
      final (left, right) = _nextStereo(type);
      data[out++] = left;
      data[out++] = right;
    }

    return data;
  }

  (double, double) _nextStereo(GeneratedNoiseType type) {
    return switch (type) {
      GeneratedNoiseType.white => (_white(), _white()),
      GeneratedNoiseType.pink => _pink(),
      GeneratedNoiseType.brown => _brown(),
    };
  }

  double _white() => _random.nextDouble() * 2 - 1;

  (double, double) _pink() {
    final whiteL = _white();
    _pinkB0L = 0.99886 * _pinkB0L + whiteL * 0.0555179;
    _pinkB1L = 0.99332 * _pinkB1L + whiteL * 0.0750759;
    _pinkB2L = 0.96900 * _pinkB2L + whiteL * 0.1538520;
    _pinkB3L = 0.86650 * _pinkB3L + whiteL * 0.3104856;
    _pinkB4L = 0.55000 * _pinkB4L + whiteL * 0.5329522;
    _pinkB5L = -0.7616 * _pinkB5L - whiteL * 0.0168980;
    final left =
        (_pinkB0L +
            _pinkB1L +
            _pinkB2L +
            _pinkB3L +
            _pinkB4L +
            _pinkB5L +
            _pinkB6L +
            whiteL * 0.5362) *
        0.11;
    _pinkB6L = whiteL * 0.115926;

    final whiteR = _white();
    _pinkB0R = 0.99886 * _pinkB0R + whiteR * 0.0555179;
    _pinkB1R = 0.99332 * _pinkB1R + whiteR * 0.0750759;
    _pinkB2R = 0.96900 * _pinkB2R + whiteR * 0.1538520;
    _pinkB3R = 0.86650 * _pinkB3R + whiteR * 0.3104856;
    _pinkB4R = 0.55000 * _pinkB4R + whiteR * 0.5329522;
    _pinkB5R = -0.7616 * _pinkB5R - whiteR * 0.0168980;
    final right =
        (_pinkB0R +
            _pinkB1R +
            _pinkB2R +
            _pinkB3R +
            _pinkB4R +
            _pinkB5R +
            _pinkB6R +
            whiteR * 0.5362) *
        0.11;
    _pinkB6R = whiteR * 0.115926;

    return (left.clamp(-1.0, 1.0), right.clamp(-1.0, 1.0));
  }

  (double, double) _brown() {
    final whiteL = _white();
    _brownLeft = (_brownLeft + 0.02 * whiteL) / 1.02;
    final left = (_brownLeft * 3.5).clamp(-1.0, 1.0);

    final whiteR = _white();
    _brownRight = (_brownRight + 0.02 * whiteR) / 1.02;
    final right = (_brownRight * 3.5).clamp(-1.0, 1.0);

    return (left, right);
  }
}
