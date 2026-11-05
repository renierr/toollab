import 'depot_summary.dart';
import 'depot_transaction.dart';

/// Value change of one year or month, split into new money and market gain,
/// plus the dividends paid out alongside.
class DepotCapitalFlow {
  final int year;
  final int? month;

  /// Money paid in minus sale proceeds taken out.
  final double newMoney;

  /// Value change not explained by new money, realized gains included.
  final double marketGain;

  /// Net dividends, paid out of the depot and so not part of its value.
  final double dividends;

  const DepotCapitalFlow({
    required this.year,
    this.month,
    required this.newMoney,
    required this.marketGain,
    required this.dividends,
  });

  double get valueChange => newMoney + marketGain;

  /// Newest year first. The portfolio starts at zero, so the first year's
  /// baseline is empty.
  static List<DepotCapitalFlow> years(
    List<DepotChartPoint> points,
    List<DepotTransaction> transactions,
  ) => _flows(points, transactions, (date) => (date.year, null));

  /// Newest month of [year] first.
  static List<DepotCapitalFlow> months(
    List<DepotChartPoint> points,
    List<DepotTransaction> transactions,
    int year,
  ) => [
    for (final flow in _flows(
      points,
      transactions,
      (date) => (date.year, date.month),
    ))
      if (flow.year == year) flow,
  ];

  static List<DepotCapitalFlow> _flows(
    List<DepotChartPoint> points,
    List<DepotTransaction> transactions,
    (int, int?) Function(DateTime date) bucketOf,
  ) {
    final last = <(int, int?), DepotChartPoint>{};
    for (final point in points) {
      last[bucketOf(point.date)] = point;
    }
    // Parqet's capital drops by the cost basis on a sale, so the realized
    // gain left the depot as well and counts as money taken out.
    final realized = <(int, int?), double>{};
    final dividends = <(int, int?), double>{};
    for (final t in transactions) {
      final bucket = bucketOf(t.datetime);
      switch (t.type) {
        case DepotTransactionType.sell:
          realized[bucket] = (realized[bucket] ?? 0) + (t.realizedGain ?? 0);
        case DepotTransactionType.dividend:
          dividends[bucket] = (dividends[bucket] ?? 0) + t.amountNet;
        default:
          break;
      }
    }
    final flows = <DepotCapitalFlow>[];
    var value = 0.0;
    var capital = 0.0;
    for (final MapEntry(key: bucket, value: point) in last.entries) {
      final newMoney = point.capital - capital - (realized[bucket] ?? 0);
      flows.add(
        DepotCapitalFlow(
          year: bucket.$1,
          month: bucket.$2,
          newMoney: newMoney,
          marketGain: point.value - value - newMoney,
          dividends: dividends[bucket] ?? 0,
        ),
      );
      value = point.value;
      capital = point.capital;
    }
    return flows.reversed.toList();
  }
}
