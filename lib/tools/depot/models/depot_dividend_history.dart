import 'depot_transaction.dart';

class DepotDividendHistory {
  final Map<(int, String), double> totals = {};
  final Map<(int, String, String, String), double> positions = {};
  int unknownCurrency = 0;
  final Map<(String, String), int> unknownByPosition = {};

  DepotDividendHistory(Iterable<DepotTransaction> transactions) {
    for (final t in transactions) {
      if (t.type != DepotTransactionType.dividend) continue;
      final currency = t.currency.trim().toUpperCase();
      if (currency.isEmpty) {
        unknownCurrency++;
        unknownByPosition.update(
          (t.portfolioId, t.holdingId),
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        continue;
      }
      final key = (t.datetime.year, currency);
      final position = (t.datetime.year, currency, t.portfolioId, t.holdingId);
      totals.update(key, (v) => v + t.amountNet, ifAbsent: () => t.amountNet);
      positions.update(
        position,
        (v) => v + t.amountNet,
        ifAbsent: () => t.amountNet,
      );
    }
  }
}
