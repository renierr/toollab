/// Dividends and interest credited in one calendar month.
class DepotIncomeMonth {
  final DateTime month;
  final double dividends;
  final double interest;

  const DepotIncomeMonth({
    required this.month,
    required this.dividends,
    required this.interest,
  });

  double get total => dividends + interest;

  static double medianTotal(Iterable<DepotIncomeMonth> months) {
    final totals = months.map((month) => month.total).toList()..sort();
    if (totals.isEmpty) return 0;
    final middle = totals.length ~/ 2;
    return totals.length.isOdd
        ? totals[middle]
        : (totals[middle - 1] + totals[middle]) / 2;
  }
}
