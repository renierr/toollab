import 'models/depot_asset_profile.dart';
import 'models/depot_holding.dart';

class DepotFundCost {
  final String key;
  final DepotHolding holding;

  /// Summed over every portfolio holding this fund.
  final double value;
  final double? expenseRatio;

  const DepotFundCost({
    required this.key,
    required this.holding,
    required this.value,
    required this.expenseRatio,
  });

  double? get yearlyCost {
    final ratio = expenseRatio;
    return ratio == null ? null : value * ratio;
  }
}

class DepotFundCosts {
  /// Funds with a known TER by yearly cost, then the rest by value.
  final List<DepotFundCost> funds;

  /// Value of all open positions.
  final double total;

  const DepotFundCosts({required this.funds, required this.total});

  Iterable<DepotFundCost> get _known =>
      funds.where((fund) => fund.expenseRatio != null);

  List<DepotFundCost> get missing => [
    for (final fund in funds)
      if (fund.expenseRatio == null) fund,
  ];

  bool get hasCosts => _known.isNotEmpty;

  double get yearlyCost =>
      _known.fold(0, (sum, fund) => sum + fund.yearlyCost!);

  double get _knownValue => _known.fold(0, (sum, fund) => sum + fund.value);

  double get _missingValue => missing.fold(0, (sum, fund) => sum + fund.value);

  /// Value-weighted TER of the funds with a known one.
  double? get fundRatio {
    final value = _knownValue;
    return value > 0 ? yearlyCost / value : null;
  }

  /// The same cost spread over the whole depot, where stocks cost nothing.
  /// Funds without a TER are left out of the base rather than counted free.
  double? get depotRatio {
    final value = total - _missingValue;
    return value > 0 && hasCosts ? yearlyCost / value : null;
  }

  /// Largest single fund cost, the scale of every row's bar.
  double get maxCost => _known.fold(0, (max, fund) {
    final cost = fund.yearlyCost!;
    return cost > max ? cost : max;
  });
}

/// The running cost of the open ETFs and funds, merged per ISIN across
/// portfolios.
DepotFundCosts depotFundCosts({
  required Iterable<DepotHolding> holdings,
  required DepotAssetProfile? Function(DepotHolding holding) profileOf,
  required DepotHoldingKind Function(DepotHolding holding) kindOf,
}) {
  final byKey = <String, DepotFundCost>{};
  var total = 0.0;
  for (final holding in holdings) {
    if (holding.isSold || holding.currentValue <= 0) continue;
    total += holding.currentValue;
    if (holding.assetType != DepotAssetType.security) continue;
    final kind = kindOf(holding);
    if (kind != DepotHoldingKind.etf && kind != DepotHoldingKind.fund) {
      continue;
    }
    final key = holding.identifier ?? holding.key;
    final previous = byKey[key];
    byKey[key] = DepotFundCost(
      key: key,
      holding: previous?.holding ?? holding,
      value: (previous?.value ?? 0) + holding.currentValue,
      expenseRatio: previous?.expenseRatio ?? profileOf(holding)?.expenseRatio,
    );
  }
  final funds = byKey.values.toList()
    ..sort((a, b) {
      final costA = a.yearlyCost;
      final costB = b.yearlyCost;
      if (costA != null && costB != null) return costB.compareTo(costA);
      if (costA != null) return -1;
      if (costB != null) return 1;
      return b.value.compareTo(a.value);
    });
  return DepotFundCosts(funds: funds, total: total);
}
