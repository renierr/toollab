import 'dart:math' as math;
import 'dart:typed_data';

/// Magnitude spectrum plus the frequency resolution of each bin.
class SpectrumResult {
  final Float64List magnitudes; // length n/2, linear magnitude per bin
  final double binHz; // frequency width of a single bin

  const SpectrumResult(this.magnitudes, this.binHz);
}

/// Dependency-free iterative radix-2 FFT and helpers used for microphone
/// frequency analysis. Input lengths must be a power of two.
class Fft {
  Fft._();

  /// In-place iterative Cooley-Tukey FFT. [re]/[im] length must be a power of 2.
  static void transform(Float64List re, Float64List im) {
    final int n = re.length;
    if (n <= 1) return;

    // Bit-reversal permutation.
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final double tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final double ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }

    for (int len = 2; len <= n; len <<= 1) {
      final double ang = -2 * math.pi / len;
      final double wr = math.cos(ang);
      final double wi = math.sin(ang);
      final int half = len >> 1;
      for (int i = 0; i < n; i += len) {
        double curR = 1.0;
        double curI = 0.0;
        for (int k = 0; k < half; k++) {
          final int a = i + k;
          final int b = a + half;
          final double vr = re[b] * curR - im[b] * curI;
          final double vi = re[b] * curI + im[b] * curR;
          re[b] = re[a] - vr;
          im[b] = im[a] - vi;
          re[a] += vr;
          im[a] += vi;
          final double nextR = curR * wr - curI * wi;
          curI = curR * wi + curI * wr;
          curR = nextR;
        }
      }
    }
  }

  /// Magnitude spectrum of real [samples] (power-of-two length) with a Hann
  /// window applied to suppress spectral leakage.
  static SpectrumResult magnitudeSpectrum(Float64List samples, int sampleRate) {
    final int n = samples.length;
    final re = Float64List(n);
    final im = Float64List(n);
    for (int i = 0; i < n; i++) {
      final double window = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
      re[i] = samples[i] * window;
    }
    transform(re, im);

    final int half = n >> 1;
    final mags = Float64List(half);
    for (int i = 0; i < half; i++) {
      mags[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]) / half;
    }
    return SpectrumResult(mags, sampleRate / n);
  }
}
