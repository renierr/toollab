import 'dart:math' as math;

import 'depot_holding.dart';
import 'depot_transaction.dart';

/// Taxable income of one year against the saver's allowance, and the open
/// losses that could still be realized against it. A rough guide: the real
/// loss pots, earlier years' losses and partial exemptions are the bank's.
class DepotTaxYear {
  final int year;

  /// Gross dividends and interest.
  final double income;

  /// Gross realized gains of stock sales; stock losses only offset these.
  final double stockGains;

  /// Gross realized gains of every other sale.
  final double otherGains;
  final double taxes;

  /// Holdings with an unrealized loss, deepest first.
  final List<DepotHolding> losers;

  const DepotTaxYear({
    required this.year,
    required this.income,
    required this.stockGains,
    required this.otherGains,
    required this.taxes,
    required this.losers,
  });

  /// A stock loss stays in its own pot, every other result offsets all income.
  double get taxable =>
      math.max(0, math.max(0, stockGains) + otherGains + income);

  double used(double allowance) => math.min(taxable, allowance);

  double free(double allowance) => math.max(0, allowance - taxable);

  double get stockLoss => _loss(true);
  double get otherLoss => _loss(false);

  double _loss(bool stock) => losers
      .where((h) => (h.kind == DepotHoldingKind.stock) == stock)
      .fold(0, (sum, h) => sum - h.unrealizedGain);

  /// Open losses that would lower this year's taxable income above the
  /// allowance.
  double offsettable(double allowance) {
    final excess = math.max(0.0, taxable - allowance);
    final fromStocks = math.min(stockLoss, math.max(0.0, stockGains));
    return math.min(excess, fromStocks + otherLoss);
  }

  static const _taxed = {
    DepotHoldingKind.stock,
    DepotHoldingKind.etf,
    DepotHoldingKind.etc,
    DepotHoldingKind.fund,
  };

  static bool isStock(DepotHolding? holding) =>
      holding?.kind == DepotHoldingKind.stock;

  /// Only [currency] bookings count; amounts are not converted.
  factory DepotTaxYear.of({
    required int year,
    required List<DepotTransaction> transactions,
    required List<DepotHolding> holdings,
    required String currency,
  }) {
    final byKey = {for (final h in holdings) (h.portfolioId, h.id): h};
    var income = 0.0, stockGains = 0.0, otherGains = 0.0, taxes = 0.0;
    final wanted = currency.trim().toUpperCase();
    for (final t in transactions) {
      if (t.datetime.year != year ||
          t.currency.trim().toUpperCase() != wanted) {
        continue;
      }
      taxes += t.tax;
      switch (t.type) {
        case DepotTransactionType.dividend || DepotTransactionType.interest:
          income += t.amountNet + t.tax;
        case DepotTransactionType.sell:
          final gain = (t.realizedGain ?? 0) + t.tax;
          if (isStock(byKey[(t.portfolioId, t.holdingId)])) {
            stockGains += gain;
          } else {
            otherGains += gain;
          }
        default:
          break;
      }
    }
    return DepotTaxYear(
      year: year,
      income: income,
      stockGains: stockGains,
      otherGains: otherGains,
      taxes: taxes,
      losers: [
        for (final h in holdings)
          if (!h.isSold &&
              h.currentValue > 0 &&
              h.unrealizedGain < 0 &&
              _taxed.contains(h.kind))
            h,
      ]..sort((a, b) => a.unrealizedGain.compareTo(b.unrealizedGain)),
    );
  }
}
