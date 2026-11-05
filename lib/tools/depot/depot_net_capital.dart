import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';

/// [points] with the capital lowered by the realized gains of all sales up to
/// each point's day, so it is the money paid in minus the money taken out.
///
/// Parqet's capital only drops by the cost of what was sold while the whole
/// proceeds leave the depot, so a realized gain would otherwise read as a
/// market loss on the day of the sale.
List<DepotChartPoint> depotNetCapital(
  List<DepotChartPoint> points,
  List<DepotTransaction> transactions,
) {
  final sales = [
    for (final t in transactions)
      if (t.type == DepotTransactionType.sell && t.realizedGain != null)
        (_day(t.datetime), t.realizedGain!),
  ];
  if (points.isEmpty || sales.isEmpty) return points;
  sales.sort((a, b) => a.$1.compareTo(b.$1));

  var sale = 0;
  var realized = 0.0;
  return [
    for (final point in points)
      () {
        final day = _day(point.date);
        while (sale < sales.length && !sales[sale].$1.isAfter(day)) {
          realized += sales[sale++].$2;
        }
        return DepotChartPoint(
          date: point.date,
          value: point.value,
          capital: point.capital - realized,
          drawdown: point.drawdown,
          live: point.live,
        );
      }(),
  ];
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
