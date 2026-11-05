import 'depot_summary.dart';

/// Time-weighted return per month and per year, in percent.
class DepotMonthlyReturns {
  /// Newest year first.
  final List<DepotYearReturns> years;

  const DepotMonthlyReturns._(this.years);

  static const empty = DepotMonthlyReturns._([]);

  bool get isEmpty => years.isEmpty;

  /// [index] is the return index of [points], one value per point.
  factory DepotMonthlyReturns.of(
    List<DepotChartPoint> points,
    List<double> index,
  ) {
    if (points.length < 2 || index.length != points.length) return empty;
    final monthEnd = <(int, int), double>{};
    for (var i = 0; i < points.length; i++) {
      final date = points[i].date;
      monthEnd[(date.year, date.month)] = index[i];
    }

    final years = <int, List<double?>>{};
    final yearEnd = <int, double>{};
    var before = 1.0;
    for (final MapEntry(key: (year, month), value: end) in monthEnd.entries) {
      final months = years.putIfAbsent(year, () => List.filled(12, null));
      if (before > 0) months[month - 1] = (end / before - 1) * 100;
      before = end;
      yearEnd[year] = end;
    }

    final result = <DepotYearReturns>[];
    var yearBefore = 1.0;
    for (final MapEntry(key: year, value: months) in years.entries) {
      final end = yearEnd[year]!;
      result.add(
        DepotYearReturns(
          year: year,
          months: months,
          total: yearBefore > 0 ? (end / yearBefore - 1) * 100 : null,
        ),
      );
      yearBefore = end;
    }
    return DepotMonthlyReturns._(result.reversed.toList());
  }
}

class DepotYearReturns {
  final int year;

  /// January first; null before the first or after the latest month.
  final List<double?> months;
  final double? total;

  const DepotYearReturns({
    required this.year,
    required this.months,
    required this.total,
  });
}
