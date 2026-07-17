import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

class DopplerPoint {
  final double time; // in seconds
  final double frequency; // in Hz
  final double magnitude; // linear peak level

  const DopplerPoint({
    required this.time,
    required this.frequency,
    required this.magnitude,
  });
}

class DopplerResult {
  final List<DopplerPoint> points;
  final double defaultFApproach;
  final double defaultFRecede;
  final double defaultT0;
  final double defaultDistance;

  const DopplerResult({
    required this.points,
    required this.defaultFApproach,
    required this.defaultFRecede,
    required this.defaultT0,
    required this.defaultDistance,
  });
}

class DopplerAnalyzer {
  DopplerAnalyzer._();

  static const int fftSize = 4096;
  static const int hopSize = 2048;
  static const double minAnalysisFreq = 150.0;
  static const double maxAnalysisFreq = 3000.0;

  /// Processes the raw mono float samples at [sampleRate] and returns a [DopplerResult].
  static DopplerResult analyze(Float32List samples, int sampleRate) {
    final List<DopplerPoint> points = [];
    final int n = samples.length;

    if (n < fftSize) {
      return const DopplerResult(
        points: [],
        defaultFApproach: 440,
        defaultFRecede: 400,
        defaultT0: 0,
        defaultDistance: 5.0,
      );
    }

    final double binHz = sampleRate / fftSize;
    final int minBin = math.max(1, (minAnalysisFreq / binHz).floor());
    final int maxBin = math.min(
      fftSize ~/ 2 - 1,
      (maxAnalysisFreq / binHz).ceil(),
    );

    final Float64List windowBuffer = Float64List(fftSize);

    // Slide window over samples
    for (int offset = 0; offset + fftSize <= n; offset += hopSize) {
      final double time = (offset + fftSize / 2) / sampleRate;

      // Copy samples to buffer
      for (int i = 0; i < fftSize; i++) {
        windowBuffer[i] = samples[offset + i].toDouble();
      }

      final SpectrumResult spec = Fft.magnitudeSpectrum(
        windowBuffer,
        sampleRate,
      );
      final Float64List mags = spec.magnitudes;

      // Find peak in our analysis band
      int peakIdx = minBin;
      double peakVal = 0.0;
      for (int i = minBin; i <= maxBin; i++) {
        if (mags[i] > peakVal) {
          peakVal = mags[i];
          peakIdx = i;
        }
      }

      // Parabolic interpolation for sub-bin accuracy
      double peakFreq = peakIdx * binHz;
      if (peakIdx > 0 && peakIdx < mags.length - 1) {
        final double a = mags[peakIdx - 1];
        final double b = mags[peakIdx];
        final double c = mags[peakIdx + 1];
        final double denom = a - 2 * b + c;
        if (denom != 0) {
          peakFreq = (peakIdx + 0.5 * (a - c) / denom) * binHz;
        }
      }

      if (peakVal > 0.0001) {
        points.add(
          DopplerPoint(time: time, frequency: peakFreq, magnitude: peakVal),
        );
      }
    }

    if (points.isEmpty) {
      return const DopplerResult(
        points: [],
        defaultFApproach: 440,
        defaultFRecede: 400,
        defaultT0: 0,
        defaultDistance: 5.0,
      );
    }

    // Estimate default parameters
    // Calculate average/median frequencies at start and end
    final int count = points.length;
    final int sectionSize = math.max(1, (count * 0.15).floor());

    // Sort frequency values in start section to get median
    final List<double> startFreqs =
        points.take(sectionSize).map((p) => p.frequency).toList()..sort();
    final double fApproach = startFreqs[startFreqs.length ~/ 2];

    // Sort frequency values in end section to get median
    final List<double> endFreqs =
        points.skip(count - sectionSize).map((p) => p.frequency).toList()
          ..sort();
    final double fRecede = endFreqs[endFreqs.length ~/ 2];

    // Center/inflection point estimation: where frequency is closest to average of fApproach and fRecede
    final double midFreq = (fApproach + fRecede) / 2.0;
    double bestDiff = double.infinity;
    double t0 = points[count ~/ 2].time;

    for (final p in points) {
      final double diff = (p.frequency - midFreq).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        t0 = p.time;
      }
    }

    return DopplerResult(
      points: points,
      defaultFApproach: fApproach,
      defaultFRecede: fRecede,
      defaultT0: t0,
      defaultDistance: 5.0,
    );
  }
}
