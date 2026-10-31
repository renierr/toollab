import 'depot_transaction.dart';

class DepotYearCurrencyReport {
  final String currency;
  final double realizedGain;
  final double dividends;
  final double interest;
  final double taxes;
  final double fees;
  final int sells;
  final int missingSaleGains;

  const DepotYearCurrencyReport({
    required this.currency,
    this.realizedGain = 0,
    this.dividends = 0,
    this.interest = 0,
    this.taxes = 0,
    this.fees = 0,
    this.sells = 0,
    this.missingSaleGains = 0,
  });

  double get total => realizedGain + dividends + interest;

  DepotYearCurrencyReport add(DepotTransaction transaction) =>
      DepotYearCurrencyReport(
        currency: currency,
        realizedGain:
            realizedGain +
            (transaction.type == DepotTransactionType.sell
                ? transaction.realizedGain ?? 0
                : 0),
        dividends:
            dividends +
            (transaction.type == DepotTransactionType.dividend
                ? transaction.amountNet
                : 0),
        interest:
            interest +
            (transaction.type == DepotTransactionType.interest
                ? transaction.amountNet
                : 0),
        taxes: taxes + transaction.tax,
        fees: fees + transaction.fee,
        sells: sells + (transaction.type == DepotTransactionType.sell ? 1 : 0),
        missingSaleGains:
            missingSaleGains +
            (transaction.type == DepotTransactionType.sell &&
                    transaction.realizedGain == null
                ? 1
                : 0),
      );
}

class DepotYearReport {
  final int year;
  final List<DepotYearCurrencyReport> currencies;
  final int unknownCurrencyCount;

  const DepotYearReport({
    required this.year,
    this.currencies = const [],
    this.unknownCurrencyCount = 0,
  });

  static List<DepotYearReport> fromTransactions(
    Iterable<DepotTransaction> transactions,
  ) {
    final years = <int, Map<String, DepotYearCurrencyReport>>{};
    final unknown = <int, int>{};
    for (final transaction in transactions) {
      final year = transaction.datetime.year;
      final groups = years.putIfAbsent(year, () => {});
      final currency = transaction.currency.trim().toUpperCase();
      if (currency.isEmpty) {
        unknown.update(year, (count) => count + 1, ifAbsent: () => 1);
        continue;
      }
      groups[currency] =
          (groups[currency] ?? DepotYearCurrencyReport(currency: currency)).add(
            transaction,
          );
    }
    final sortedYears = years.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final year in sortedYears)
        DepotYearReport(
          year: year,
          currencies: List.unmodifiable(
            years[year]!.values.toList()
              ..sort((a, b) => a.currency.compareTo(b.currency)),
          ),
          unknownCurrencyCount: unknown[year] ?? 0,
        ),
    ];
  }
}
