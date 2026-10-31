import 'dart:math' as math;

import 'models/depot_asset_profile.dart';
import 'models/depot_holding.dart';
import 'models/depot_summary.dart';

class DepotRiskContribution {
  final DepotHolding holding;
  final double weight;

  const DepotRiskContribution({required this.holding, required this.weight});
}

class DepotRiskExposure {
  final String name;
  final double weight;
  final List<DepotRiskContribution> contributors;

  const DepotRiskExposure({
    required this.name,
    required this.weight,
    this.contributors = const [],
  });
}

class DepotRiskBreakdown {
  final DepotRiskExposure? largest;
  final double coverage;
  final List<DepotRiskContribution> missingSecurities;
  final List<DepotRiskContribution> otherAssets;

  const DepotRiskBreakdown({
    this.largest,
    this.coverage = 0,
    this.missingSecurities = const [],
    this.otherAssets = const [],
  });

  double get missingWeight =>
      missingSecurities.fold(0, (v, item) => v + item.weight);
  double get otherWeight => otherAssets.fold(0, (v, item) => v + item.weight);
}

class DepotRisk {
  final double topOne;
  final double topThree;
  final double crypto;
  final List<DepotRiskContribution> positions;
  final double? currentDrawdown;
  final double? maxDrawdown;
  final double? bestDay;
  final double? worstDay;
  final DepotRiskBreakdown country;
  final DepotRiskBreakdown sector;

  const DepotRisk({
    required this.topOne,
    required this.topThree,
    required this.crypto,
    this.positions = const [],
    this.currentDrawdown,
    this.maxDrawdown,
    this.bestDay,
    this.worstDay,
    this.country = const DepotRiskBreakdown(),
    this.sector = const DepotRiskBreakdown(),
  });

  static DepotRisk calculate(
    List<DepotHolding> holdings,
    List<DepotChartPoint> chart, {
    DepotAssetProfile? Function(DepotHolding)? profileOf,
  }) {
    final open =
        holdings
            .where(
              (h) => !h.isSold && h.currentValue.isFinite && h.currentValue > 0,
            )
            .toList()
          ..sort((a, b) => b.currentValue.compareTo(a.currentValue));
    final total = open.fold<double>(0, (v, h) => v + h.currentValue);
    double weight(Iterable<DepotHolding> items) => total <= 0
        ? 0
        : items.fold<double>(0, (v, h) => v + h.currentValue) / total * 100;
    final validPoints = chart
        .where((p) => p.value.isFinite && p.value > 0)
        .toList();
    double? current;
    double? maximum;
    double? bestDay;
    double? worstDay;
    DepotChartPoint? previous;
    var peak = 0.0;
    for (final p in validPoints) {
      if (previous != null) {
        final day = DateTime.utc(p.date.year, p.date.month, p.date.day);
        final before = DateTime.utc(
          previous.date.year,
          previous.date.month,
          previous.date.day,
        );
        if (day.difference(before).inDays == 1) {
          final change = (p.value / previous.value - 1) * 100;
          bestDay = math.max(bestDay ?? change, change);
          worstDay = math.min(worstDay ?? change, change);
        }
      }
      peak = math.max(peak, p.value);
      current = (p.value / peak - 1) * 100;
      maximum = math.min(maximum ?? 0, current);
      previous = p;
    }

    DepotRiskBreakdown breakdown(bool country) {
      if (total <= 0) return const DepotRiskBreakdown();
      final values = <String, List<DepotRiskContribution>>{};
      final missing = <DepotRiskContribution>[];
      final other = <DepotRiskContribution>[];
      var classified = 0.0;
      void add(String name, DepotHolding holding, double value) {
        if (name.trim().isEmpty || !value.isFinite || value <= 0) return;
        classified += value;
        (values[name] ??= []).add(
          DepotRiskContribution(holding: holding, weight: value / total * 100),
        );
      }

      for (final h in open) {
        if (h.assetType != DepotAssetType.security) {
          other.add(
            DepotRiskContribution(
              holding: h,
              weight: h.currentValue / total * 100,
            ),
          );
          continue;
        }
        final before = classified;
        final profile = profileOf?.call(h);
        if (profile != null) {
          final shares = country ? profile.countryShares : profile.sectorShares;
          final single = country ? profile.country : profile.sector;
          final valid = shares.entries.where(
            (e) => e.value.isFinite && e.value > 0,
          );
          final sum = valid.fold<double>(0, (a, b) => a + b.value);
          if (shares.isNotEmpty && sum > 0 && sum <= 1.001) {
            for (final entry in valid) {
              add(
                entry.key,
                h,
                h.currentValue * entry.value / math.max(1, sum),
              );
            }
          } else if (single != null) {
            add(single, h, h.currentValue);
          }
        }
        final missingValue = (h.currentValue - (classified - before)).clamp(
          0,
          h.currentValue,
        );
        if (missingValue > 0) {
          missing.add(
            DepotRiskContribution(
              holding: h,
              weight: missingValue / total * 100,
            ),
          );
        }
      }
      DepotRiskExposure? largest;
      for (final entry in values.entries) {
        final sources = entry.value
          ..sort((a, b) => b.weight.compareTo(a.weight));
        final sum = sources.fold<double>(0, (v, item) => v + item.weight);
        if (largest == null || sum > largest.weight) {
          largest = DepotRiskExposure(
            name: entry.key,
            weight: sum,
            contributors: List.unmodifiable(sources),
          );
        }
      }
      return DepotRiskBreakdown(
        largest: largest,
        coverage: (classified / total * 100).clamp(0, 100),
        missingSecurities: List.unmodifiable(
          missing..sort((a, b) => b.weight.compareTo(a.weight)),
        ),
        otherAssets: List.unmodifiable(
          other..sort((a, b) => b.weight.compareTo(a.weight)),
        ),
      );
    }

    return DepotRisk(
      topOne: weight(open.take(1)),
      topThree: weight(open.take(3)),
      crypto: weight(open.where((h) => h.assetType == DepotAssetType.crypto)),
      positions: List.unmodifiable(
        open
            .take(3)
            .map(
              (h) => DepotRiskContribution(
                holding: h,
                weight: h.currentValue / total * 100,
              ),
            ),
      ),
      currentDrawdown: validPoints.length < 2 ? null : current,
      maxDrawdown: validPoints.length < 2 ? null : maximum,
      bestDay: bestDay,
      worstDay: worstDay,
      country: breakdown(true),
      sector: breakdown(false),
    );
  }
}
