import 'models/depot_summary.dart';

/// One fall below an all-time high, from Parqet's drawdown figure.
class DepotDrawdown {
  /// The last high before the fall.
  final DateTime peak;
  final DateTime low;

  /// Deepest point in percent, negative.
  final double depth;

  /// Back at the old high; null while still below.
  final DateTime? recovered;

  const DepotDrawdown({
    required this.peak,
    required this.low,
    required this.depth,
    required this.recovered,
  });

  Duration? get recovery => recovered?.difference(peak);
}

class DepotDrawdowns {
  /// Falls of at least [minDepth] percent, deepest first, the ongoing one
  /// included.
  final List<DepotDrawdown> drops;

  /// The ongoing fall at any depth; null at an all-time high.
  final DepotDrawdown? current;

  /// Value of the newest point, in percent.
  final double currentDepth;

  const DepotDrawdowns._({
    required this.drops,
    required this.current,
    required this.currentDepth,
  });

  static const empty = DepotDrawdowns._(
    drops: [],
    current: null,
    currentDepth: 0,
  );

  static const double minDepth = 5;

  bool get isEmpty => drops.isEmpty && current == null;

  DepotDrawdown? get deepest => drops.isEmpty ? null : drops.first;

  Duration? get averageRecovery {
    final recoveries = [for (final drop in drops) ?drop.recovery];
    if (recoveries.isEmpty) return null;
    final total = recoveries.fold(Duration.zero, (sum, d) => sum + d);
    return total ~/ recoveries.length;
  }

  factory DepotDrawdowns.of(List<DepotChartPoint> points) {
    if (points.length < 2) return empty;
    final all = <DepotDrawdown>[];
    var peak = points.first.date;
    DepotDrawdown? open;
    for (final point in points) {
      // Parqet reports exactly zero at a high; allow float noise.
      if (point.drawdown > -1e-6) {
        if (open != null) {
          all.add(
            DepotDrawdown(
              peak: open.peak,
              low: open.low,
              depth: open.depth,
              recovered: point.date,
            ),
          );
          open = null;
        }
        peak = point.date;
      } else if (open == null || point.drawdown < open.depth) {
        open = DepotDrawdown(
          peak: peak,
          low: point.date,
          depth: point.drawdown,
          recovered: null,
        );
      }
    }
    if (open != null) all.add(open);
    return DepotDrawdowns._(
      drops: [
        for (final drop in all)
          if (drop.depth <= -minDepth) drop,
      ]..sort((a, b) => a.depth.compareTo(b.depth)),
      current: open,
      currentDepth: points.last.drawdown,
    );
  }
}
