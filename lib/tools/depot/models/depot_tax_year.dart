import 'dart:math' as math;

import 'depot_advance_lump.dart';
import 'depot_holding.dart';
import 'depot_transaction.dart';

/// Taxable income of one year against the saver's allowance, and the open
/// losses that could still be realized against it. A rough guide: the real
/// loss pots and earlier years' losses are the bank's.
class DepotTaxYear {
  final int year;

  /// Gross dividends and interest.
  final double income;

  /// Gross realized gains of stock sales; stock losses only offset these.
  final double stockGains;

  /// Gross realized gains of every other sale.
  final double otherGains;

  /// Tax-free part of fund income and fund gains (partial exemption).
  final double exempt;
  final double taxes;

  /// Holdings with an unrealized loss, deepest first.
  final List<DepotHolding> losers;

  /// Running year only: next January's advance lump sums of funds.
  final List<DepotAdvanceLump> advanceLumps;

  const DepotTaxYear({
    required this.year,
    required this.income,
    required this.stockGains,
    required this.otherGains,
    required this.exempt,
    required this.taxes,
    required this.losers,
    this.advanceLumps = const [],
  });

  /// A stock loss stays in its own pot, every other result offsets all income.
  double get taxable =>
      math.max(0, math.max(0, stockGains) + otherGains + income - exempt);

  double get advanceLumpTotal =>
      advanceLumps.fold(0, (sum, lump) => sum + lump.taxable);

  double used(double allowance) => math.min(taxable, allowance);

  double free(double allowance) => math.max(0, allowance - taxable);

  double get stockLoss => _loss(true);
  double get otherLoss => _loss(false);

  /// A fund's loss counts without its partially exempt share.
  double _loss(bool stock) => losers
      .where((h) => (h.kind == DepotHoldingKind.stock) == stock)
      .fold(
        0,
        (sum, h) =>
            sum -
            h.unrealizedGain *
                (1 - (DepotAdvanceLump.partialExemption(h) ?? 0)),
      );

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

  /// Only [currency] bookings count; amounts are not converted. [ytd] is the
  /// holdings' year-to-date performance and [baseRate] the running year's
  /// base rate, both for the advance lump sums.
  factory DepotTaxYear.of({
    required int year,
    required List<DepotTransaction> transactions,
    required List<DepotHolding> holdings,
    required String currency,
    required Map<String, DepotHoldingPerformance> ytd,
    required double? baseRate,
  }) {
    final byKey = {for (final h in holdings) (h.portfolioId, h.id): h};
    var income = 0.0, stockGains = 0.0, otherGains = 0.0;
    var exempt = 0.0, taxes = 0.0;
    final wanted = currency.trim().toUpperCase();
    for (final t in transactions) {
      if (t.datetime.year != year ||
          t.currency.trim().toUpperCase() != wanted) {
        continue;
      }
      taxes += t.tax;
      final holding = byKey[(t.portfolioId, t.holdingId)];
      final exemption = holding == null
          ? 0.0
          : DepotAdvanceLump.partialExemption(holding) ?? 0.0;
      switch (t.type) {
        case DepotTransactionType.dividend || DepotTransactionType.interest:
          final gross = t.amountNet + t.tax;
          income += gross;
          exempt += gross * exemption;
        case DepotTransactionType.sell:
          final gain = (t.realizedGain ?? 0) + t.tax;
          exempt += gain * exemption;
          if (isStock(holding)) {
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
      exempt: exempt,
      taxes: taxes,
      advanceLumps: year == DateTime.now().year
          ? DepotAdvanceLump.estimate(
              year: year,
              rate: baseRate,
              holdings: holdings,
              transactions: transactions,
              ytd: ytd,
            )
          : const [],
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
