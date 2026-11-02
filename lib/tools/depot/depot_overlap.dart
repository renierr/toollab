import 'dart:math' as math;

import 'models/depot_asset_profile.dart';
import 'models/depot_holding.dart';

enum DepotOverlapLevel {
  low,
  moderate,
  high;

  static DepotOverlapLevel of(double overlap) => overlap >= 0.15
      ? high
      : overlap >= 0.05
      ? moderate
      : low;
}

class DepotOverlapShare {
  final String key;
  final String name;
  final double weightA;
  final double weightB;
  final bool heldDirectly;

  const DepotOverlapShare({
    required this.key,
    required this.name,
    required this.weightA,
    required this.weightB,
    this.heldDirectly = false,
  });

  double get overlap => math.min(weightA, weightB);
}

class DepotOverlapPair {
  final DepotHolding a;
  final DepotHolding b;

  /// Sum of the smaller weight of every shared holding, as a fund share.
  final double overlap;
  final List<DepotOverlapShare> shared;

  /// Share of each fund its published holdings describe.
  final double coverageA;
  final double coverageB;

  const DepotOverlapPair({
    required this.a,
    required this.b,
    required this.overlap,
    required this.shared,
    required this.coverageA,
    required this.coverageB,
  });

  DepotOverlapLevel get level => DepotOverlapLevel.of(overlap);
}

class DepotOverlap {
  /// Funds with published holdings, largest position first.
  final List<DepotHolding> funds;

  /// Every fund pair, highest overlap first.
  final List<DepotOverlapPair> pairs;

  const DepotOverlap({required this.funds, required this.pairs});

  bool get hasPairs => pairs.isNotEmpty;

  DepotOverlapPair? pairOf(DepotHolding a, DepotHolding b) {
    for (final pair in pairs) {
      if ((pair.a.key == a.key && pair.b.key == b.key) ||
          (pair.a.key == b.key && pair.b.key == a.key)) {
        return pair;
      }
    }
    return null;
  }
}

/// Pairwise overlap of the open ETFs and funds, from their top holdings.
DepotOverlap depotOverlap({
  required Iterable<DepotHolding> holdings,
  required DepotAssetProfile? Function(DepotHolding holding) profileOf,
  required DepotHoldingKind Function(DepotHolding holding) kindOf,
}) {
  final funds = <DepotHolding>[];
  final weights = <String, Map<String, double>>{};
  final names = <String, String>{};
  final direct = <String>{};

  for (final holding in holdings) {
    if (holding.isSold ||
        holding.currentValue <= 0 ||
        holding.assetType != DepotAssetType.security) {
      continue;
    }
    final kind = kindOf(holding);
    if (kind == DepotHoldingKind.stock) {
      direct.add(holding.isin ?? holding.symbol ?? holding.id);
      continue;
    }
    if (kind != DepotHoldingKind.etf && kind != DepotHoldingKind.fund) continue;
    final constituents = profileOf(holding)?.constituents ?? const [];
    final merged = <String, double>{};
    for (final constituent in constituents) {
      if (!constituent.weight.isFinite || constituent.weight <= 0) continue;
      merged.update(
        constituent.key,
        (weight) => weight + constituent.weight,
        ifAbsent: () => constituent.weight,
      );
      names.putIfAbsent(constituent.key, () => constituent.name);
    }
    if (merged.isEmpty) continue;
    funds.add(holding);
    weights[holding.key] = merged;
  }
  funds.sort((a, b) => b.currentValue.compareTo(a.currentValue));

  double coverage(Map<String, double> fund) =>
      fund.values.fold<double>(0, (sum, w) => sum + w).clamp(0, 1);

  final pairs = <DepotOverlapPair>[];
  for (var i = 0; i < funds.length; i++) {
    for (var j = i + 1; j < funds.length; j++) {
      final a = weights[funds[i].key]!;
      final b = weights[funds[j].key]!;
      final shared = [
        for (final entry in a.entries)
          if (b[entry.key] case final weightB?)
            DepotOverlapShare(
              key: entry.key,
              name: names[entry.key]!,
              weightA: entry.value,
              weightB: weightB,
              heldDirectly: direct.contains(entry.key),
            ),
      ]..sort((x, y) => y.overlap.compareTo(x.overlap));
      pairs.add(
        DepotOverlapPair(
          a: funds[i],
          b: funds[j],
          overlap: shared
              .fold<double>(0, (sum, s) => sum + s.overlap)
              .clamp(0, 1),
          shared: List.unmodifiable(shared),
          coverageA: coverage(a),
          coverageB: coverage(b),
        ),
      );
    }
  }
  pairs.sort((x, y) => y.overlap.compareTo(x.overlap));
  return DepotOverlap(
    funds: List.unmodifiable(funds),
    pairs: List.unmodifiable(pairs),
  );
}
