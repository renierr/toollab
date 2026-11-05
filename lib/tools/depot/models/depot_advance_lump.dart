import 'dart:math' as math;

import 'depot_holding.dart';
import 'depot_transaction.dart';

/// Estimated advance lump sum (Vorabpauschale) of one fund for a running
/// year, charged in the following January.
class DepotAdvanceLump {
  final DepotHolding holding;

  /// Taxable amount after the partial exemption.
  final double taxable;

  const DepotAdvanceLump({required this.holding, required this.taxable});

  /// Base rate the BMF publishes each January, the default of the setting.
  static const Map<int, double> baseRates = {
    2023: 0.0255,
    2024: 0.0229,
    2025: 0.0253,
    2026: 0.0320,
  };

  /// Funds of [holdings] with an estimate, highest first. The year's end
  /// price is today's, so it moves until December.
  static List<DepotAdvanceLump> estimate({
    required int year,
    required double? rate,
    required List<DepotHolding> holdings,
    required List<DepotTransaction> transactions,
    required Map<String, DepotHoldingPerformance> ytd,
  }) {
    if (rate == null || rate <= 0) return const [];
    final result = <DepotAdvanceLump>[];
    for (final holding in holdings) {
      final exemption = partialExemption(holding);
      if (exemption == null || holding.isSold || holding.shares <= 0) continue;
      final gain = ytd[holding.key]?.gain;
      if (gain == null) continue;

      var bought = 0.0, boughtShares = 0.0, proceeds = 0.0, soldShares = 0.0;
      var distributions = 0.0;
      // Shares bought in the year count one twelfth less per full month
      // before the month of purchase.
      var boughtWeighted = 0.0;
      for (final t in transactions) {
        if (t.datetime.year != year ||
            t.portfolioId != holding.portfolioId ||
            t.holdingId != holding.id) {
          continue;
        }
        switch (t.type) {
          case DepotTransactionType.buy || DepotTransactionType.transferIn:
            bought += t.amount;
            boughtShares += t.shares;
            boughtWeighted += t.shares * (13 - t.datetime.month) / 12;
          case DepotTransactionType.sell || DepotTransactionType.transferOut:
            proceeds += t.amount;
            soldShares += t.shares;
          case DepotTransactionType.dividend:
            distributions += t.amountNet + t.tax;
          default:
            break;
        }
      }

      final startShares = holding.shares - boughtShares + soldShares;
      final startValue =
          holding.currentValue + proceeds + distributions - bought - gain;
      final price = holding.currentValue / holding.shares;
      final startPrice = startShares > 0 ? startValue / startShares : price;
      if (startPrice <= 0) continue;
      // Sales are taken from the oldest shares first.
      final heldAllYear = math.max(0.0, startShares - soldShares);
      final shares = heldAllYear + boughtShares;
      final base = startPrice * 0.7 * rate * (heldAllYear + boughtWeighted);
      final increase = (price - startPrice) * shares + distributions;
      final lump = math.max(0.0, math.min(base, increase) - distributions);
      final taxable = lump * (1 - exemption);
      if (taxable >= 1) {
        result.add(DepotAdvanceLump(holding: holding, taxable: taxable));
      }
    }
    return result..sort((a, b) => b.taxable.compareTo(a.taxable));
  }

  static final _bond = RegExp(
    r'\b(Bond|Bonds|Aggregate|Treasury|Govt|Government|Corporate|Anleihen?'
    r'|Renten|Money Market|Geldmarkt)\b',
    caseSensitive: false,
  );

  /// Share of fund income that is tax free: 30 % for equity funds, none for
  /// bond funds; null for anything that is not a fund. Told by the name.
  static double? partialExemption(DepotHolding holding) =>
      switch (holding.kind) {
        DepotHoldingKind.etf ||
        DepotHoldingKind.fund => _bond.hasMatch(holding.name) ? 0 : 0.3,
        _ => null,
      };
}
