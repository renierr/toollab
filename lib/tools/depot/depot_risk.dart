import 'dart:math' as math;

import 'models/depot_holding.dart';
import 'models/depot_asset_profile.dart';
import 'models/depot_summary.dart';

class DepotRisk {
  final double topOne;
  final double topThree;
  final double crypto;
  final double? currentDrawdown;
  final double? maxDrawdown;
  final double? bestDay;
  final double? worstDay;
  final ({String name, double weight})? country;
  final ({String name, double weight})? sector;

  const DepotRisk({
    required this.topOne,
    required this.topThree,
    required this.crypto,
    this.currentDrawdown,
    this.maxDrawdown,
    this.bestDay,
    this.worstDay,
    this.country,
    this.sector,
  });

  static DepotRisk calculate(
    List<DepotHolding> holdings,
    List<DepotChartPoint> chart, {
    DepotAssetProfile? Function(DepotHolding)? profileOf,
  }) {
    final open = holdings.where((h) => !h.isSold && h.currentValue > 0).toList()
      ..sort((a, b) => b.currentValue.compareTo(a.currentValue));
    final total = open.fold<double>(0, (v, h) => v + h.currentValue);
    double weight(Iterable<DepotHolding> items) => total <= 0
        ? 0
        : items.fold<double>(0, (v, h) => v + h.currentValue) / total * 100;
    double? current;
    double? maximum;
    double? bestDay;
    double? worstDay;
    DepotChartPoint? previous;
    var peak = 0.0;
    for (final p in chart) {
      if (!p.value.isFinite || p.value <= 0) continue;
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
    ({String name, double weight})? largest(bool country) {
      if (profileOf == null || total <= 0) return null;
      final values = <String, double>{};
      for (final h in open) {
        final profile = profileOf(h);
        if (profile == null) continue;
        final shares = country ? profile.countryShares : profile.sectorShares;
        final single = country ? profile.country : profile.sector;
        final valid = shares.entries.where(
          (e) => e.value.isFinite && e.value > 0,
        );
        final sum = valid.fold<double>(0, (a, b) => a + b.value);
        if (shares.isNotEmpty && sum > 0 && sum <= 1.001) {
          for (final entry in valid) {
            values.update(
              entry.key,
              (v) => v + h.currentValue * entry.value / math.max(1, sum),
              ifAbsent: () => h.currentValue * entry.value / math.max(1, sum),
            );
          }
        } else if (single != null) {
          values.update(
            single,
            (v) => v + h.currentValue,
            ifAbsent: () => h.currentValue,
          );
        }
      }
      if (values.isEmpty) return null;
      final first = values.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return (name: first.key, weight: first.value / total * 100);
    }

    return DepotRisk(
      topOne: weight(open.take(1)),
      topThree: weight(open.take(3)),
      crypto: weight(open.where((h) => h.assetType == DepotAssetType.crypto)),
      currentDrawdown: current,
      maxDrawdown: maximum,
      bestDay: bestDay,
      worstDay: worstDay,
      country: largest(true),
      sector: largest(false),
    );
  }
}
