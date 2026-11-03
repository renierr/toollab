import 'depot_summary.dart';

/// Value change of one year or month, split into new money and market gain.
class DepotCapitalFlow {
  final int year;
  final int? month;

  /// Change of the net invested capital.
  final double newMoney;

  /// Value change not explained by new money, realized gains included.
  final double marketGain;

  const DepotCapitalFlow({
    required this.year,
    this.month,
    required this.newMoney,
    required this.marketGain,
  });

  double get valueChange => newMoney + marketGain;

  /// Newest year first. The portfolio starts at zero, so the first year's
  /// baseline is empty.
  static List<DepotCapitalFlow> years(List<DepotChartPoint> points) =>
      _flows(points, (date) => (date.year, null));

  /// Newest month of [year] first.
  static List<DepotCapitalFlow> months(
    List<DepotChartPoint> points,
    int year,
  ) => [
    for (final flow in _flows(points, (date) => (date.year, date.month)))
      if (flow.year == year) flow,
  ];

  static List<DepotCapitalFlow> _flows(
    List<DepotChartPoint> points,
    (int, int?) Function(DateTime date) bucketOf,
  ) {
    final last = <(int, int?), DepotChartPoint>{};
    for (final point in points) {
      last[bucketOf(point.date)] = point;
    }
    final flows = <DepotCapitalFlow>[];
    var value = 0.0;
    var capital = 0.0;
    for (final MapEntry(key: (year, month), value: point) in last.entries) {
      final newMoney = point.capital - capital;
      flows.add(
        DepotCapitalFlow(
          year: year,
          month: month,
          newMoney: newMoney,
          marketGain: point.value - value - newMoney,
        ),
      );
      value = point.value;
      capital = point.capital;
    }
    return flows.reversed.toList();
  }
}
