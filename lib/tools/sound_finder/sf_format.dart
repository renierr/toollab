/// Formats a frequency in Hz to a compact human string, e.g. `440 Hz` or
/// `1.2 kHz`. Units are universal symbols and kept inline.
String formatHz(double hz) {
  if (hz >= 1000) {
    final double khz = hz / 1000;
    return '${khz.toStringAsFixed(khz >= 10 ? 1 : 2)} kHz';
  }
  return '${hz.toStringAsFixed(hz >= 100 ? 0 : 1)} Hz';
}

/// Sample rate without rounding, e.g. `22.05 kHz` or `48 kHz`.
String formatRate(int hz) =>
    hz % 1000 == 0 ? '${hz ~/ 1000} kHz' : '${hz / 1000} kHz';

/// `m:ss`, or `h:mm:ss` past an hour.
String formatClock(Duration d) {
  final int total = d.inSeconds;
  final int h = total ~/ 3600;
  final int m = (total % 3600) ~/ 60;
  final String s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
