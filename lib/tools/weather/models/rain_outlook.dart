enum RainOutlookKind { rainingNow, rainStops, rainSoon, dry }

class RainOutlook {
  const RainOutlook(this.kind, [this.minutes = 0]);

  static const double threshold = 0.1;

  final RainOutlookKind kind;
  final int minutes;

  /// Null until the frames needed for an answer have arrived.
  static RainOutlook? from(
    List<double?> series,
    List<DateTime> times,
    int nowIndex,
  ) {
    if (series.isEmpty || nowIndex >= series.length) return null;
    final now = series[nowIndex];
    if (now == null) return null;
    int minutesTo(int i) => times[i].difference(times[nowIndex]).inMinutes;
    if (now >= threshold) {
      for (var i = nowIndex + 1; i < series.length - 1; i++) {
        final a = series[i];
        final b = series[i + 1];
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
      if (v >= threshold) {
        return RainOutlook(RainOutlookKind.rainSoon, minutesTo(i));
      }
    }
    return const RainOutlook(RainOutlookKind.dry);
  }
}
