import 'depot_return_index.dart';
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

/// The climb from a listed fall's low to the high where the next one starts.
class DepotRise {
  final DateTime start;
  final DateTime end;

  /// Time-weighted return in percent.
  final double percent;

  /// Value change minus new money.
  final double gain;

  /// Still climbing; [end] is the newest point.
  final bool ongoing;

  const DepotRise({
    required this.start,
    required this.end,
    required this.percent,
    required this.gain,
    required this.ongoing,
  });

  Duration get duration => end.difference(start);
}

class DepotDrawdowns {
  /// Falls of at least [minDepth] percent, deepest first, the ongoing one
  /// included.
  final List<DepotDrawdown> drops;

  /// The ongoing fall at any depth; null at an all-time high.
  final DepotDrawdown? current;

  /// Value of the newest point, in percent.
  final double currentDepth;

  /// Rises of at least [minDepth] percent, strongest first, the ongoing one
  /// included at any size.
  final List<DepotRise> rises;

  const DepotDrawdowns._({
    required this.drops,
    required this.current,
    required this.currentDepth,
    required this.rises,
  });

  static const empty = DepotDrawdowns._(
    drops: [],
    current: null,
    currentDepth: 0,
    rises: [],
  );

  static const double minDepth = 5;

  bool get isEmpty => drops.isEmpty && current == null && rises.isEmpty;

  DepotDrawdown? get deepest => drops.isEmpty ? null : drops.first;

  DepotRise? get strongest => rises.isEmpty ? null : rises.first;

  DepotRise? get currentRise {
    for (final rise in rises) {
      if (rise.ongoing) return rise;
    }
    return null;
  }

  Duration? get averageRecovery =>
      _average([for (final drop in drops) ?drop.recovery]);

  Duration? get averageRise => _average([
    for (final rise in rises)
      if (!rise.ongoing) rise.duration,
  ]);

  static Duration? _average(List<Duration> durations) {
    if (durations.isEmpty) return null;
    final total = durations.fold(Duration.zero, (sum, d) => sum + d);
    return total ~/ durations.length;
  }

  /// [index] is the [depotReturnIndex] of [points].
  factory DepotDrawdowns.of(List<DepotChartPoint> points, List<double> index) {
    if (points.length < 2 || index.length != points.length) return empty;
    final falls = <_Fall>[];
    var peak = 0;
    _Fall? open;
    for (var i = 0; i < points.length; i++) {
      // Parqet reports exactly zero at a high; allow float noise.
      if (points[i].drawdown > -1e-6) {
        if (open != null) falls.add(open..recovered = i);
        open = null;
        peak = i;
      } else if (open == null) {
        open = _Fall(peak, i, points[i].drawdown);
      } else if (points[i].drawdown < open.depth) {
        open
          ..low = i
          ..depth = points[i].drawdown;
      }
    }
    if (open != null) falls.add(open);
    final listed = [
      for (final fall in falls)
        if (fall.depth <= -minDepth) fall,
    ];

    DepotDrawdown drop(_Fall fall) => DepotDrawdown(
      peak: points[fall.peak].date,
      low: points[fall.low].date,
      depth: fall.depth,
      recovered: switch (fall.recovered) {
        final i? => points[i].date,
        null => null,
      },
    );

    final last = points.length - 1;
    final starts = [0, for (final fall in listed) fall.low];
    final ends = [for (final fall in listed) fall.peak, last];
    final rises = <DepotRise>[];
    for (var i = 0; i < starts.length; i++) {
      final (a, b) = (starts[i], ends[i]);
      if (b <= a || index[a] <= 0) continue;
      final rise = DepotRise(
        start: points[a].date,
        end: points[b].date,
        percent: (index[b] / index[a] - 1) * 100,
        gain:
            points[b].value -
            points[a].value -
            (points[b].capital - points[a].capital),
        ongoing: b == last,
      );
      if (rise.ongoing ? rise.percent > 0 : rise.percent >= minDepth) {
        rises.add(rise);
      }
    }

    return DepotDrawdowns._(
      drops: [for (final fall in listed) drop(fall)]
        ..sort((a, b) => a.depth.compareTo(b.depth)),
      current: open == null ? null : drop(open),
      currentDepth: points.last.drawdown,
      rises: rises..sort((a, b) => b.percent.compareTo(a.percent)),
    );
  }
}

class _Fall {
  final int peak;
  int low;
  double depth;
  int? recovered;

  _Fall(this.peak, this.low, this.depth);
}
