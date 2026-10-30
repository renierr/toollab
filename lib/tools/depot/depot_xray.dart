import 'models/depot_asset_profile.dart';
import 'models/depot_holding.dart';

class DepotXRaySource {
  final DepotHolding holding;
  final DepotHoldingKind kind;
  final double value;

  /// Share of the fund; null for a directly held stock.
  final double? fundWeight;

  const DepotXRaySource({
    required this.holding,
    required this.kind,
    required this.value,
    this.fundWeight,
  });
}

class DepotXRayEntry {
  final String key;
  final String name;
  final double value;
  final List<DepotXRaySource> sources;

  const DepotXRayEntry({
    required this.key,
    required this.name,
    required this.value,
    required this.sources,
  });
}

class DepotXRay {
  final List<DepotXRayEntry> entries;

  /// Value of all open positions, the base for every share.
  final double total;

  /// Fund value outside the published top holdings, or of funds without any.
  final double uncovered;

  /// Whether any fund was looked through; without one the X-Ray only repeats
  /// the position list.
  final bool hasLookThrough;

  const DepotXRay({
    required this.entries,
    required this.total,
    required this.uncovered,
    required this.hasLookThrough,
  });
}

/// Direct stocks plus each fund's top holdings scaled by the fund's value,
/// merged per company, largest first.
DepotXRay depotXRay({
  required Iterable<DepotHolding> holdings,
  required DepotAssetProfile? Function(DepotHolding holding) profileOf,
  required DepotHoldingKind Function(DepotHolding holding) kindOf,
}) {
  final names = <String, String>{};
  final values = <String, double>{};
  final sources = <String, List<DepotXRaySource>>{};
  var total = 0.0;
  var uncovered = 0.0;
  var hasLookThrough = false;

  void add(
    String key,
    String name,
    DepotXRaySource source, {
    bool direct = false,
  }) {
    if (direct || !names.containsKey(key)) names[key] = name;
    values.update(key, (v) => v + source.value, ifAbsent: () => source.value);
    (sources[key] ??= []).add(source);
  }

  for (final holding in holdings) {
    if (holding.isSold || holding.currentValue <= 0) continue;
    final value = holding.currentValue;
    total += value;
    if (holding.assetType != DepotAssetType.security) continue;
    final kind = kindOf(holding);
    if (kind == DepotHoldingKind.stock) {
      add(
        holding.isin ?? holding.symbol ?? holding.id,
        holding.name,
        DepotXRaySource(holding: holding, kind: kind, value: value),
        direct: true,
      );
      continue;
    }
    final constituents = profileOf(holding)?.constituents ?? const [];
    var covered = 0.0;
    for (final constituent in constituents) {
      if (covered + constituent.weight > 1.001) break;
      covered += constituent.weight;
      add(
        constituent.key,
        constituent.name,
        DepotXRaySource(
          holding: holding,
          kind: kind,
          value: value * constituent.weight,
          fundWeight: constituent.weight,
        ),
      );
    }
    if (covered > 0) hasLookThrough = true;
    uncovered += value * (1 - covered.clamp(0, 1));
  }

  final entries = [
    for (final entry in values.entries)
      DepotXRayEntry(
        key: entry.key,
        name: names[entry.key]!,
        value: entry.value,
        sources: sources[entry.key]!
          ..sort((a, b) => b.value.compareTo(a.value)),
      ),
  ]..sort((a, b) => b.value.compareTo(a.value));
  return DepotXRay(
    entries: entries,
    total: total,
    uncovered: uncovered,
    hasLookThrough: hasLookThrough,
  );
}
