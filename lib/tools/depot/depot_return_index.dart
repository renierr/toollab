import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';

/// Growth of 1 per chart point with new money taken out of each step's value
/// change, so it moves with the market only (time-weighted).
List<double> depotReturnIndex(
  List<DepotChartPoint> points,
  List<DepotTransaction> transactions,
) {
  if (points.isEmpty) return const [];
  // Parqet's capital drops by the cost basis on a sale while the value drops
  // by the proceeds, so the realized gain is money taken out, not a loss.
  final sales = [
    for (final t in transactions)
      if (t.type == DepotTransactionType.sell && t.realizedGain != null)
        (_day(t.datetime), t.realizedGain!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var sale = 0;
  bool saleBy(DateTime day) =>
      sale < sales.length && !sales[sale].$1.isAfter(day);
  while (saleBy(_day(points.first.date))) {
    sale++;
  }

  final index = [1.0];
  for (var i = 1; i < points.length; i++) {
    final before = points[i - 1];
    final point = points[i];
    final day = _day(point.date);
    var realized = 0.0;
    while (saleBy(day)) {
      realized += sales[sale++].$2;
    }
    final newMoney = point.capital - before.capital - realized;
    index.add(
      before.value > 0
          ? index.last * (point.value - newMoney) / before.value
          : index.last,
    );
  }
  return index;
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
