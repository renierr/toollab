import 'depot_region.dart';
import 'models/depot_asset_profile.dart';
import 'models/depot_holding.dart';

enum DepotAllocationDimension { sector, industry, region }

/// Current value per category across open positions, largest first. A `null`
/// key collects positions that have no metadata (yet).
Map<String?, double> depotAllocationBreakdown({
  required Iterable<DepotHolding> holdings,
  required DepotAssetProfile? Function(DepotHolding holding) profileOf,
  required DepotAllocationDimension dimension,
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
        add(profile?.industry, value);
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
    if (total > 0) {
      for (final entry in shares.entries) {
        add(entry.key, value * entry.value / total);
      }
      return;
    }
  }
  add(single, value);
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
    if (total > 0) {
      for (final entry in shares.entries) {
        add(DepotRegion.of(entry.key).name, value * entry.value / total);
      }
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
