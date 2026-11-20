import 'dart:math' as math;

import 'weather_condition.dart';
import 'weather_history_entry.dart';

enum HistoryPeriod { day, week, month, year }

/// A local calendar period: `[start, end)`, weeks starting on Monday.
class HistoryRange {
  const HistoryRange._(this.period, this.start, this.end);

  /// The [days] days up to and including today, bucketed by day.
  factory HistoryRange.lastDays(int days, DateTime now) {
    final t = now.toLocal();
    final end = DateTime(t.year, t.month, t.day + 1);
    return HistoryRange._(
      HistoryPeriod.week,
      DateTime(end.year, end.month, end.day - days),
      end,
    );
  }

  factory HistoryRange.containing(HistoryPeriod period, DateTime time) {
    final t = time.toLocal();
    return switch (period) {
      HistoryPeriod.day => HistoryRange._(
        period,
        DateTime(t.year, t.month, t.day),
        DateTime(t.year, t.month, t.day + 1),
      ),
      HistoryPeriod.week => HistoryRange._(
        period,
        DateTime(t.year, t.month, t.day - (t.weekday - 1)),
        DateTime(t.year, t.month, t.day - (t.weekday - 1) + 7),
      ),
      HistoryPeriod.month => HistoryRange._(
        period,
        DateTime(t.year, t.month),
        DateTime(t.year, t.month + 1),
      ),
      HistoryPeriod.year => HistoryRange._(
        period,
        DateTime(t.year),
        DateTime(t.year + 1),
      ),
    };
  }

  final HistoryPeriod period;
  final DateTime start;
  final DateTime end;

  HistoryRange shift(int steps) => HistoryRange.containing(
    period,
    switch (period) {
      HistoryPeriod.day => DateTime(start.year, start.month, start.day + steps),
      HistoryPeriod.week => DateTime(
        start.year,
        start.month,
        start.day + 7 * steps,
      ),
      HistoryPeriod.month => DateTime(start.year, start.month + steps),
      HistoryPeriod.year => DateTime(start.year + steps),
    },
  );

  /// The same period one year earlier, for the comparison.
  HistoryRange previousYear() => HistoryRange.containing(
    period,
    DateTime(start.year - 1, start.month, start.day),
  );

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// Hours the period has had up to [now]; future hours cannot be recorded.
  int elapsedHours(DateTime now) {
    final until = now.isBefore(end) ? now : end;
    if (!until.isAfter(start)) return 0;
    return until.difference(start).inHours;
  }

  @override
  bool operator ==(Object other) =>
      other is HistoryRange && other.period == period && other.start == start;

  @override
  int get hashCode => Object.hash(period, start);
}

/// Aggregated values of a run of hours: a day, a month or a whole period.
class HistoryBucket {
  HistoryBucket._(this.start, List<WeatherHistoryEntry> hours)
    : hours = hours.length,
      measuredHours = hours.where((h) => h.isMeasured).length,
      minTemperature = _min(hours, (h) => h.temperature),
      maxTemperature = _max(hours, (h) => h.temperature),
      meanTemperature = _mean(hours, (h) => h.temperature),
      precipitation = _sum(hours, (h) => h.precipitation),
      sunshineMinutes = _sum(hours, (h) => h.sunshineMinutes),
      maxGust = _max(hours, (h) => h.windGust),
      meanWind = _mean(hours, (h) => h.windSpeed),
      condition = _dominant(hours);

  /// Local start of the bucket.
  final DateTime start;
  final int hours;
  final int measuredHours;
  final double? minTemperature;
  final double? maxTemperature;
  final double? meanTemperature;
  final double precipitation;
  final double sunshineMinutes;
  final double? maxGust;
  final double? meanWind;
  final WeatherCondition? condition;

  static Iterable<double> _values(
    List<WeatherHistoryEntry> hours,
    double? Function(WeatherHistoryEntry) pick,
  ) => hours.map(pick).nonNulls;

  static double? _min(
    List<WeatherHistoryEntry> h,
    double? Function(WeatherHistoryEntry) pick,
  ) {
    final v = _values(h, pick);
    return v.isEmpty ? null : v.reduce(math.min);
  }

  static double? _max(
    List<WeatherHistoryEntry> h,
    double? Function(WeatherHistoryEntry) pick,
  ) {
    final v = _values(h, pick);
    return v.isEmpty ? null : v.reduce(math.max);
  }

  static double? _mean(
    List<WeatherHistoryEntry> h,
    double? Function(WeatherHistoryEntry) pick,
  ) {
    final v = _values(h, pick).toList();
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  static double _sum(
    List<WeatherHistoryEntry> h,
    double? Function(WeatherHistoryEntry) pick,
  ) => _values(h, pick).fold(0, (a, b) => a + b);

  /// Daytime weather decides the symbol, like the forecast's day summary.
  static WeatherCondition? _dominant(List<WeatherHistoryEntry> hours) {
    final counts = <WeatherCondition, int>{};
    for (final h in hours) {
      final hour = h.hour.toLocal().hour;
      final c = h.condition;
      if (c != null && hour >= 8 && hour <= 18) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// Everything the history screen shows for one period.
class HistorySummary {
  HistorySummary._({
    required this.range,
    required this.entries,
    required this.total,
    required this.days,
    required this.buckets,
  });

  factory HistorySummary.of(
    List<WeatherHistoryEntry> entries,
    HistoryRange range,
  ) {
    final inRange = [
      for (final e in entries)
        if (range.contains(e.hour.toLocal())) e,
    ];
    final days = _group(inRange, (t) => DateTime(t.year, t.month, t.day));
    final buckets = range.period == HistoryPeriod.year
        ? _group(inRange, (t) => DateTime(t.year, t.month))
        : days;
    return HistorySummary._(
      range: range,
      entries: inRange,
      total: HistoryBucket._(range.start, inRange),
      days: days,
      buckets: buckets,
    );
  }

  /// A day with at least this much precipitation counts as a rain day.
  static const double rainDayMm = 1.0;

  final HistoryRange range;
  final List<WeatherHistoryEntry> entries;
  final HistoryBucket total;
  final List<HistoryBucket> days;

  /// Chart points: days for a week or month, months for a year.
  final List<HistoryBucket> buckets;

  bool get isEmpty => entries.isEmpty;

  WeatherHistoryEntry? get coldestHour => _extreme(isMax: false);
  WeatherHistoryEntry? get warmestHour => _extreme(isMax: true);

  HistoryBucket? get warmestDay => _day((d) => d.maxTemperature, isMax: true);
  HistoryBucket? get coldestDay => _day((d) => d.minTemperature, isMax: false);
  HistoryBucket? get wettestDay =>
      _day((d) => d.precipitation > 0 ? d.precipitation : null, isMax: true);

  int get rainDays => days.where((d) => d.precipitation >= rainDayMm).length;

  /// Share of the elapsed hours that were recorded, 0…1.
  double coverage(DateTime now) {
    final expected = range.elapsedHours(now);
    return expected == 0 ? 0 : math.min(1, entries.length / expected);
  }

  WeatherHistoryEntry? _extreme({required bool isMax}) {
    WeatherHistoryEntry? best;
    for (final e in entries) {
      final t = e.temperature;
      if (t == null) continue;
      final b = best?.temperature;
      if (b == null || (isMax ? t > b : t < b)) best = e;
    }
    return best;
  }

  HistoryBucket? _day(
    double? Function(HistoryBucket) pick, {
    required bool isMax,
  }) {
    HistoryBucket? best;
    for (final d in days) {
      final v = pick(d);
      if (v == null) continue;
      final b = best == null ? null : pick(best);
      if (b == null || (isMax ? v > b : v < b)) best = d;
    }
    return best;
  }

  static List<HistoryBucket> _group(
    List<WeatherHistoryEntry> entries,
    DateTime Function(DateTime local) key,
  ) {
    final groups = <DateTime, List<WeatherHistoryEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(key(e.hour.toLocal()), () => []).add(e);
    }
    final keys = groups.keys.toList()..sort();
    return [for (final k in keys) HistoryBucket._(k, groups[k]!)];
  }
}
