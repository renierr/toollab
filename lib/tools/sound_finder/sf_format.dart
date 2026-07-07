/// Formats a frequency in Hz to a compact human string, e.g. `440 Hz` or
/// `1.2 kHz`. Units are universal symbols and kept inline.
String formatHz(double hz) {
  if (hz >= 1000) {
    final double khz = hz / 1000;
    return '${khz.toStringAsFixed(khz >= 10 ? 1 : 2)} kHz';
  }
  return '${hz.toStringAsFixed(hz >= 100 ? 0 : 1)} Hz';
}
