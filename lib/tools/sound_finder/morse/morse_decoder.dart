import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'morse_converter.dart';

class MorseDecoder {
  MorseDecoder._();

  /// Runs the full Morse decoding sequence on a background isolate.
  static Future<String> decode({
    required Float32List samples,
    required int sampleRate,
  }) {
    return compute(_decodeIsolate, <String, dynamic>{
      'samples': samples,
      'sampleRate': sampleRate,
    });
  }
}

String _decodeIsolate(Map<String, dynamic> args) {
  final Float32List samples = args['samples'] as Float32List;
  final int sampleRate = args['sampleRate'] as int;

  if (samples.isEmpty) return '';

  // 1. Normalize audio (automatic gain control)
  final Float32List normalized = _normalizeAudio(samples);

  // 2. Detect dominant tone frequency (default standard Morse frequency is ~600Hz)
  final double dominantFreq = _detectToneFrequency(normalized, sampleRate);

  // 3. Simple bandpass filter centered on dominant frequency
  final Float32List filtered = _applyBandpass(
    normalized,
    dominantFreq,
    sampleRate,
  );

  // 4. Calculate RMS envelope
  // 5ms window size, 50% overlap (hop size = window / 2)
  final int windowSize = (sampleRate * 0.005).floor();
  final int hopSize = (windowSize / 2).floor();
  List<double> envelope = [];

  for (int i = 0; i < filtered.length - windowSize; i += hopSize) {
    double sumSq = 0;
    for (int j = 0; j < windowSize; j++) {
      final double s = filtered[i + j];
      sumSq += s * s;
    }
    envelope.add(math.sqrt(sumSq / windowSize));
  }

  if (envelope.isEmpty) return '';

  // 5. Apply median filter to remove pops/clicks (~15ms window)
  final int medianWindow = math.max(
    3,
    (15 / ((1000 / sampleRate) * hopSize)).floor(),
  );
  envelope = _medianFilter(envelope, medianWindow);

  // 6. Smooth envelope using moving average (~20ms window)
  final int smoothWindow = math.max(
    3,
    (20 / ((1000 / sampleRate) * hopSize)).floor(),
  );
  envelope = _smoothEnvelope(envelope, smoothWindow);

  // 7. Calculate adaptive thresholds based on envelope distribution
  final thresholds = _calculateAdaptiveThresholds(envelope);
  final double highThreshold = thresholds['high']!;
  final double lowThreshold = thresholds['low']!;

  if (highThreshold <= lowThreshold || highThreshold == 0) {
    return '';
  }

  // 8. Schmitt trigger with hysteresis
  List<bool> states = _schmittTrigger(envelope, highThreshold, lowThreshold);

  // 9. Debounce states to remove tiny glitches (< 10ms)
  final int minDebounce = math.max(
    2,
    (10 / ((1000 / sampleRate) * hopSize)).floor(),
  );
  states = _debounceStates(states, minDebounce);

  // 10. Run Length Encoding
  final List<_Run> runs = [];
  if (states.isNotEmpty) {
    bool currentState = states[0];
    int currentCount = 0;
    for (final s in states) {
      if (s == currentState) {
        currentCount++;
      } else {
        runs.add(_Run(state: currentState, count: currentCount));
        currentState = s;
        currentCount = 1;
      }
    }
    runs.add(_Run(state: currentState, count: currentCount));
  }

  // Filter leading/trailing silences and insignificant transitions
  final List<_Run> filteredRuns = runs.where((r) {
    if (r.state) return r.count >= minDebounce;
    // Keep silence runs if they lie between sound signals
    final int idx = runs.indexOf(r);
    final bool hasPrevOn = runs.sublist(0, idx).any((p) => p.state);
    final bool hasNextOn = runs.sublist(idx + 1).any((n) => n.state);
    return hasPrevOn && hasNextOn;
  }).toList();

  // 11. Estimate Unit Length
  final List<int> onDurations = filteredRuns
      .where((r) => r.state)
      .map((r) => r.count)
      .toList();
  if (onDurations.isEmpty) return '';

  final double unitLength = _estimateUnitLength(onDurations);
  if (unitLength <= 0) return '';

  // 12. Parse Morse code dots, dashes, and gaps
  final StringBuffer morseBuffer = StringBuffer();
  const double dotDashThreshold = 2.0;
  const double charGapThreshold = 2.0;
  const double wordGapThreshold = 5.0;

  for (final run in filteredRuns) {
    final double units = run.count / unitLength;

    if (run.state) {
      // Sound active: Dot vs Dash
      if (units < dotDashThreshold) {
        morseBuffer.write('.');
      } else {
        morseBuffer.write('-');
      }
    } else {
      // Silence active: Char gap vs Word gap
      if (units < charGapThreshold) {
        // Inter-element silence, ignore
      } else if (units < wordGapThreshold) {
        morseBuffer.write(' ');
      } else {
        morseBuffer.write(' / ');
      }
    }
  }

  final String morse = morseBuffer
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (morse.isEmpty) return '';

  // Translate Morse representation to text
  return MorseConverter.morseToText(morse);
}

class _Run {
  final bool state;
  final int count;
  const _Run({required this.state, required this.count});
}

Float32List _normalizeAudio(Float32List data) {
  double maxAbs = 0;
  for (int i = 0; i < data.length; i++) {
    final double abs = data[i].abs();
    if (abs > maxAbs) maxAbs = abs;
  }
  if (maxAbs < 0.001) return data;

  final Float32List out = Float32List(data.length);
  final double scale = 0.9 / maxAbs;
  for (int i = 0; i < data.length; i++) {
    out[i] = data[i] * scale;
  }
  return out;
}

double _goertzelMagnitude(Float32List data, double targetFreq, int sampleRate) {
  final int k = ((data.length * targetFreq) / sampleRate).round();
  final double w = (2 * math.pi * k) / data.length;
  final double cosW = math.cos(w);
  final double coeff = 2 * cosW;

  double s0 = 0;
  double s1 = 0;
  double s2 = 0;

  for (int i = 0; i < data.length; i++) {
    s0 = data[i] + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }

  return s1 * s1 + s2 * s2 - coeff * s1 * s2;
}

double _detectToneFrequency(Float32List data, int sampleRate) {
  final List<double> testFreqs = [400, 500, 600, 700, 800, 1000];
  double maxMag = 0;
  double dominant = 600;

  final int windowSize = math.min(8192, data.length);
  final Float32List window = Float32List.sublistView(data, 0, windowSize);

  for (final freq in testFreqs) {
    final double mag = _goertzelMagnitude(window, freq, sampleRate);
    if (mag > maxMag) {
      maxMag = mag;
      dominant = freq;
    }
  }
  return dominant;
}

Float32List _applyBandpass(
  Float32List data,
  double centerFreq,
  int sampleRate,
) {
  final Float32List out = Float32List(data.length);
  final double fc = centerFreq / sampleRate;
  const double qFactor = 10.0;

  final double w0 = 2 * math.pi * fc;
  final double alpha = math.sin(w0) / (2 * qFactor);

  final double b0 = alpha;
  final double b2 = -alpha;
  final double a0 = 1 + alpha;
  final double a1 = -2 * math.cos(w0);
  final double a2 = 1 - alpha;

  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  final double b0a0 = b0 / a0;
  final double b2a0 = b2 / a0;
  final double a1a0 = a1 / a0;
  final double a2a0 = a2 / a0;

  for (int i = 0; i < data.length; i++) {
    final double x = data[i];
    final double y = b0a0 * x + b2a0 * x2 - a1a0 * y1 - a2a0 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    out[i] = y;
  }
  return out;
}

List<double> _medianFilter(List<double> envelope, int windowSize) {
  final List<double> result = List.filled(envelope.length, 0);
  final int halfWindow = windowSize ~/ 2;

  for (int i = 0; i < envelope.length; i++) {
    final List<double> values = [];
    for (int j = -halfWindow; j <= halfWindow; j++) {
      final int idx = i + j;
      if (idx >= 0 && idx < envelope.length) {
        values.add(envelope[idx]);
      }
    }
    values.sort();
    result[i] = values[values.length ~/ 2];
  }
  return result;
}

List<double> _smoothEnvelope(List<double> envelope, int windowSize) {
  final List<double> result = List.filled(envelope.length, 0);
  final int halfWindow = windowSize ~/ 2;

  for (int i = 0; i < envelope.length; i++) {
    double sum = 0;
    int count = 0;
    for (int j = -halfWindow; j <= halfWindow; j++) {
      final int idx = i + j;
      if (idx >= 0 && idx < envelope.length) {
        sum += envelope[idx];
        count++;
      }
    }
    result[i] = sum / count;
  }
  return result;
}

Map<String, double> _calculateAdaptiveThresholds(List<double> envelope) {
  final List<double> sorted = List.from(envelope)..sort();
  final double noiseFloor = sorted[(sorted.length * 0.1).floor()];
  final double signalLevel = sorted[(sorted.length * 0.9).floor()];

  final double range = signalLevel - noiseFloor;
  return {'high': noiseFloor + range * 0.4, 'low': noiseFloor + range * 0.2};
}

List<bool> _schmittTrigger(List<double> envelope, double high, double low) {
  final List<bool> states = List.filled(envelope.length, false);
  bool currentState = false;

  for (int i = 0; i < envelope.length; i++) {
    if (currentState) {
      if (envelope[i] < low) {
        currentState = false;
      }
    } else {
      if (envelope[i] > high) {
        currentState = true;
      }
    }
    states[i] = currentState;
  }
  return states;
}

List<bool> _debounceStates(List<bool> states, int minDuration) {
  if (states.isEmpty) return [];

  final List<bool> result = List.from(states);
  final List<_Run> runs = [];
  bool current = states[0];
  int start = 0;

  for (int i = 1; i <= states.length; i++) {
    if (i == states.length || states[i] != current) {
      runs.add(_Run(state: current, count: i - start));
      if (i < states.length) {
        current = states[i];
        start = i;
      }
    }
  }

  int index = 0;
  for (final run in runs) {
    if (run.count < minDuration) {
      final bool prev = index > 0 ? runs[index - 1].state : run.state;
      final bool next = index < runs.length - 1
          ? runs[index + 1].state
          : run.state;
      final bool newState = prev == next ? prev : run.state;

      for (int j = 0; j < run.count; j++) {
        result[index + j] = newState;
      }
    }
    index += run.count;
  }
  return result;
}

double _estimateUnitLength(List<int> onDurations) {
  final List<int> sorted = List.from(onDurations)..sort();
  if (sorted.length == 1) return sorted[0].toDouble();

  double dotCenter = sorted[0].toDouble();
  double dashCenter = sorted.last.toDouble();

  for (int iter = 0; iter < 10; iter++) {
    final List<int> dots = [];
    final List<int> dashes = [];

    for (final d in sorted) {
      if ((d - dotCenter).abs() < (d - dashCenter).abs()) {
        dots.add(d);
      } else {
        dashes.add(d);
      }
    }

    if (dots.isNotEmpty) {
      dotCenter = dots.reduce((a, b) => a + b) / dots.length;
    }
    if (dashes.isNotEmpty) {
      dashCenter = dashes.reduce((a, b) => a + b) / dashes.length;
    }
  }

  final double ratio = dashCenter / dotCenter;
  if (ratio >= 2.0 && ratio <= 5.0) {
    return dotCenter;
  }

  // Fallback to average of lower quartile
  final List<int> lowerQuartile = sorted.sublist(
    0,
    math.max(1, sorted.length ~/ 3),
  );
  return lowerQuartile.reduce((a, b) => a + b) / lowerQuartile.length;
}
