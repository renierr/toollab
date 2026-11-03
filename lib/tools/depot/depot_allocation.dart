import 'depot_region.dart';
import 'models/depot_asset_profile.dart';
import 'models/depot_fund_constituent.dart';
import 'models/depot_holding.dart';

enum DepotAllocationDimension { sector, industry, region }

/// Industry key for fund value outside the published top holdings.
const String depotAllocationFundRest = '\u0000fund-rest';

/// Current value per category across open positions, largest first. A `null`
/// key collects positions that have no metadata (yet). With [kindOf] and
/// [constituentProfileOf], industry looks through ETFs and funds to their top
/// holdings and files the remainder under [depotAllocationFundRest].
Map<String?, double> depotAllocationBreakdown({
  required Iterable<DepotHolding> holdings,
  required DepotAssetProfile? Function(DepotHolding holding) profileOf,
  required DepotAllocationDimension dimension,
  DepotHoldingKind Function(DepotHolding holding)? kindOf,
  DepotAssetProfile? Function(DepotFundConstituent constituent)?
  constituentProfileOf,
}) {
  final buckets = <String?, double>{};
  void add(String? key, double value) {
    if (value <= 0) return;
    buckets.update(key, (current) => current + value, ifAbsent: () => value);
  }

  for (final holding in holdings) {
    if (holding.isSold || holding.currentValue <= 0) continue;
    final profile = profileOf(holding);
    final value = holding.currentValue;
    switch (dimension) {
      case DepotAllocationDimension.sector:
        _addShares(add, profile?.sectorShares, profile?.sector, value);
      case DepotAllocationDimension.industry:
        final kind = kindOf?.call(holding);
        if (constituentProfileOf != null &&
            (kind == DepotHoldingKind.etf || kind == DepotHoldingKind.fund)) {
          _addFundIndustries(
            add,
            profile?.constituents ?? const [],
            constituentProfileOf,
            value,
          );
        } else {
          add(profile?.industry, value);
        }
      case DepotAllocationDimension.region:
        _addRegions(add, profile, value);
    }
  }

  final entries = buckets.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final entry in entries) entry.key: entry.value};
}

void _addShares(
  void Function(String? key, double value) add,
  Map<String, double>? shares,
  String? single,
  double value,
) {
  if (shares != null && shares.isNotEmpty) {
    final total = shares.values.fold<double>(0, (a, b) => a + b);
    if (total > 0 && total <= 1.001) {
      final divisor = total > 1 ? total : 1.0;
      for (final entry in shares.entries) {
        add(entry.key, value * entry.value / divisor);
      }
      add(null, value * (1 - total / divisor));
      return;
    }
  }
  add(single, value);
}

void _addFundIndustries(
  void Function(String? key, double value) add,
  List<DepotFundConstituent> constituents,
  DepotAssetProfile? Function(DepotFundConstituent constituent) profileOf,
  double value,
) {
  var covered = 0.0;
  for (final constituent in constituents) {
    if (covered + constituent.weight > 1.001) break;
    covered += constituent.weight;
    add(profileOf(constituent)?.industry, value * constituent.weight);
  }
  add(depotAllocationFundRest, value * (1 - covered.clamp(0, 1)));
}

void _addRegions(
  void Function(String? key, double value) add,
  DepotAssetProfile? profile,
  double value,
) {
  if (profile == null) {
    add(null, value);
    return;
  }
  final shares = profile.countryShares;
  if (shares.isNotEmpty) {
    final total = shares.values.fold<double>(0, (a, b) => a + b);
    if (total > 0 && total <= 1.001) {
      final divisor = total > 1 ? total : 1.0;
      for (final entry in shares.entries) {
        add(DepotRegion.of(entry.key).name, value * entry.value / divisor);
      }
      add(null, value * (1 - total / divisor));
      return;
    }
  }
  if (profile.country != null) {
    add(DepotRegion.of(profile.country).name, value);
    return;
  }
  if (DepotRegion.values.any((region) => region.name == profile.region)) {
    add(profile.region, value);
    return;
  }
  add(null, value);
}
