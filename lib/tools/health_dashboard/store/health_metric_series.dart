import 'dart:math' as math;

/// One day of a metric, as a drilldown needs it.
class HealthMetricDay {
  final DateTime day;
  final double? value;
  final double? lo;
  final double? hi;
  final int count;

  const HealthMetricDay({
    required this.day,
    this.value,
    this.lo,
    this.hi,
    this.count = 0,
  });
}

/// A metric's day window plus the figures its summary card shows.
///
/// Drilldowns load this from the store instead of filtering the dashboard's
/// in-memory record list: that list only holds the few types the cards read, so
/// every other metric drilled down into an empty page even with rows stored.
class HealthMetricSeries {
  final List<HealthMetricDay> days;

  /// True for metrics whose window figure is a sum (steps, distance), false for
  /// the ones that average (heart rate, weight).
  final bool sum;

  const HealthMetricSeries({required this.days, required this.sum});

  List<double?> get values => [for (final day in days) day.value];

  /// The window's last day, which is the day the navigation selects.
  double? get selectedDayValue => days.isEmpty ? null : days.last.value;

  bool get hasData => days.any((day) => day.value != null);

  double? get totalOrAverage {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return null;
    final total = present.reduce((a, b) => a + b);
    return sum ? total : total / present.length;
  }

  /// Extremes span the individual readings, not the daily figures, so a day's
  /// low is visible even when the day itself is shown as an average.
  double? get min =>
      _extreme((day) => day.lo ?? day.value, (a, b) => math.min(a, b));

  double? get max =>
      _extreme((day) => day.hi ?? day.value, (a, b) => math.max(a, b));

  double? _extreme(
    double? Function(HealthMetricDay day) pick,
    double Function(double a, double b) fold,
  ) {
    final present = days.map(pick).whereType<double>().toList();
    return present.isEmpty ? null : present.reduce(fold);
  }
}
