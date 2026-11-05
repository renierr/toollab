import '../models/depot_dividend.dart';
import '../models/depot_holding.dart';

/// A stock's dividend per share now against a comparable earlier payment.
class DepotDividendChange {
  final DepotHolding holding;
  final double before;
  final double now;

  /// Listing currency of both amounts.
  final String currency;

  const DepotDividendChange({
    required this.holding,
    required this.before,
    required this.now,
    required this.currency,
  });

  double get percent => (now / before - 1) * 100;
}

class DepotDividendChanges {
  /// Smaller moves are rounding or currency noise.
  static const double minPercent = 0.5;

  /// Stocks whose latest payment in [year] differs from a comparable earlier
  /// one: quarterly payers against the last payment before the year, monthly
  /// ones by the median of three, the others against the payment about a year
  /// earlier, since their interim and final payments often differ. Raises
  /// first, strongest first.
  static List<DepotDividendChange> of({
    required int year,
    required List<DepotHolding> holdings,
    required Map<String, DepotDividendAsset> assets,
  }) {
    final changes = <DepotDividendChange>[];
    for (final holding in holdings) {
      if (holding.isSold || holding.kind != DepotHoldingKind.stock) continue;
      final asset = assets[holding.identifier];
      if (asset == null) continue;
      final events = _regular(asset.events);
      if (events.length < 2 || events.last.exDate.year != year) continue;
      final latest = events.last;
      final earlier = [
        for (final e in events)
          if (e.exDate.year < year) e,
      ];
      final double? before;
      var now = latest.amount;
      switch (DepotDividendFrequency.of(events)) {
        case DepotDividendFrequency.monthly:
          // Monthly payers often add supplementals; the median of the last
          // three payments on each side steps over them.
          before = earlier.isEmpty ? null : _median(earlier);
          now = _median([
            for (final e in events)
              if (e.exDate.year == year) e,
          ]);
        case DepotDividendFrequency.quarterly:
          before = earlier.isEmpty ? null : earlier.last.amount;
        default:
          before = _yearBefore(events, latest)?.amount;
      }
      if (before == null || before <= 0) continue;
      final change = DepotDividendChange(
        holding: holding,
        before: before,
        now: now,
        currency: asset.currency,
      );
      if (change.percent.abs() >= minPercent) changes.add(change);
    }
    return changes..sort((a, b) => b.percent.compareTo(a.percent));
  }

  /// Positive payments without one-off specials: a jump of more than half
  /// that the next payment falls back from.
  static List<DepotDividendEvent> _regular(List<DepotDividendEvent> events) {
    final paid = [
      for (final e in events)
        if (e.amount > 0) e,
    ];
    return [
      for (var i = 0; i < paid.length; i++)
        if (!(i > 0 &&
            i + 1 < paid.length &&
            paid[i].amount > paid[i - 1].amount * 1.5 &&
            paid[i + 1].amount < paid[i].amount * 0.75))
          paid[i],
    ];
  }

  static double _median(List<DepotDividendEvent> events) {
    final last = [
      for (final e in events.skip(events.length > 3 ? events.length - 3 : 0))
        e.amount,
    ]..sort();
    return last[last.length ~/ 2];
  }

  /// The payment closest to a year before [latest], within six weeks.
  static DepotDividendEvent? _yearBefore(
    List<DepotDividendEvent> events,
    DepotDividendEvent latest,
  ) {
    final target = latest.exDate.subtract(const Duration(days: 365));
    DepotDividendEvent? best;
    var bestGap = 43;
    for (final e in events) {
      final gap = e.exDate.difference(target).inDays.abs();
      if (gap < bestGap) {
        best = e;
        bestGap = gap;
      }
    }
    return best;
  }
}
