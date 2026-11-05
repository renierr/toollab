import 'models/depot_summary.dart';

/// Growth of 1 per chart point with new money taken out of each step's value
/// change, so it moves with the market only (time-weighted). Expects net
/// capital, see `depotNetCapital`.
List<double> depotReturnIndex(List<DepotChartPoint> points) {
  if (points.isEmpty) return const [];
  final index = [1.0];
  for (var i = 1; i < points.length; i++) {
    final before = points[i - 1];
    final point = points[i];
    final newMoney = point.capital - before.capital;
    index.add(
      before.value > 0
          ? index.last * (point.value - newMoney) / before.value
          : index.last,
    );
  }
  return index;
}
