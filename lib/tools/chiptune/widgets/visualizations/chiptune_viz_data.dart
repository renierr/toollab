/// Centralized audio data snapshot distributed to all visualizations once per
/// frame by [ChiptuneVisualizerPanel]. Eliminates redundant per-viz SoLoud pulls.
class VizData {
  /// 128 FFT bins, 0.0 – 1.0.
  final List<double> freq;

  /// 256 waveform samples, -1.0 – 1.0.
  final List<double> wave;

  /// Average energy of the lowest 8 FFT bins, 0.0 – 1.0.
  final double bass;

  /// Seconds elapsed since the previous frame.
  final double deltaTime;

  VizData({
    required this.freq,
    required this.wave,
    required this.bass,
    required this.deltaTime,
  });
}
