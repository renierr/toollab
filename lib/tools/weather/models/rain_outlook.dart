enum RainOutlookKind { rainingNow, rainStops, rainSoon, dry }

class RainOutlook {
  const RainOutlook(this.kind, [this.minutes = 0]);

  static const double threshold = 0.1;

  final RainOutlookKind kind;
  final int minutes;

  /// Null until the frames needed for an answer have arrived; NaN entries
  /// (frames without an image) are skipped.
  static RainOutlook? from(
    List<double?> series,
    List<DateTime> times,
    int nowIndex,
  ) {
    if (series.isEmpty || nowIndex >= series.length) return null;
    final now = series[nowIndex];
    if (now == null || now.isNaN) return null;
    int minutesTo(int i) => times[i].difference(times[nowIndex]).inMinutes;
    if (now >= threshold) {
      final known = [
        for (var i = nowIndex + 1; i < series.length; i++)
          if (series[i] == null || !series[i]!.isNaN) i,
      ];
      for (var k = 0; k < known.length - 1; k++) {
        final i = known[k];
        final a = series[i];
        final b = series[known[k + 1]];
        if (a == null || b == null) {
          return const RainOutlook(RainOutlookKind.rainingNow);
        }
        if (a < threshold && b < threshold) {
          return RainOutlook(RainOutlookKind.rainStops, minutesTo(i));
        }
      }
      return const RainOutlook(RainOutlookKind.rainingNow);
    }
    for (var i = nowIndex + 1; i < series.length; i++) {
      final v = series[i];
      if (v == null) return null;
      if (v.isNaN) continue;
      if (v >= threshold) {
        return RainOutlook(RainOutlookKind.rainSoon, minutesTo(i));
      }
    }
    return const RainOutlook(RainOutlookKind.dry);
  }
}
