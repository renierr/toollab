import 'dart:math';

import 'health_models.dart';

typedef HealthSpan = ({int t0, int t1, double v});

/// Same-writer duplicates the primary key cannot collapse: a watch re-uploading
/// a run with shifted bounds or a corrected value, or writing a whole-workout
/// record on top of its per-minute buckets. Applied when totals are read; the
/// stored rows stay as Health Connect has them.
class HealthOverlap {
  HealthOverlap._();

  /// A row more than half covered by rows already counted is a double count.
  static const double coveredRatio = 0.5;

  /// Same ratio as the cross-writer session mirror, against the longer side.
  static const double sessionRatio = 0.7;

  /// How far back a covering row can start; the longest record a writer emits
  /// is a whole-day total.
  static const int lookbackMillis = Duration.millisecondsPerDay;

  /// Sort key for [Sweep]: start ascending, then the longer and larger row
  /// first, so a re-upload with a later end or a corrected value wins.
  static int compare(HealthSpan a, HealthSpan b) {
    final byStart = a.t0.compareTo(b.t0);
    if (byStart != 0) return byStart;
    final byEnd = b.t1.compareTo(a.t1);
    if (byEnd != 0) return byEnd;
    return b.v.compareTo(a.v);
  }

  /// The rows of one writer and metric that count, in [compare] order.
  static List<HealthSpan> distinct(Iterable<HealthSpan> rows) {
    final sorted = rows.toList()..sort(compare);
    final sweep = Sweep();
    return [
      for (final row in sorted)
        if (sweep.keeps(row)) row,
    ];
  }

  /// Drops a session the same writer stored twice for the same activity:
  /// overlapping by [sessionRatio] of the longer one. The longer copy stays,
  /// then the one with a distance, then the lower id.
  static List<HealthSession> distinctSessions(List<HealthSession> sessions) {
    if (sessions.length < 2) return sessions;
    final ranked = [...sessions]..sort(_sessionRank);
    final kept = <HealthSession>[];
    for (final session in ranked) {
      if (!kept.any((other) => _sameActivity(session, other))) {
        kept.add(session);
      }
    }
    return [
      for (final session in sessions)
        if (kept.contains(session)) session,
    ];
  }

  static int _sessionRank(HealthSession a, HealthSession b) {
    final byLength = (b.t1 - b.t0).compareTo(a.t1 - a.t0);
    if (byLength != 0) return byLength;
    final byDistance = (b.distanceKm != null ? 1 : 0).compareTo(
      a.distanceKm != null ? 1 : 0,
    );
    if (byDistance != 0) return byDistance;
    return a.id.compareTo(b.id);
  }

  static bool _sameActivity(HealthSession a, HealthSession b) {
    if (a.package != b.package ||
        a.kind != b.kind ||
        a.activity != b.activity) {
      return false;
    }
    final overlap = min(a.t1, b.t1) - max(a.t0, b.t0);
    if (overlap <= 0) return false;
    final longer = max(max(1, a.t1 - a.t0), b.t1 - b.t0);
    return overlap / longer >= sessionRatio;
  }
}

/// Walks one writer's rows in [HealthOverlap.compare] order and decides which
/// count. Stateful so a long range can be fed in windows.
class Sweep {
  int? _coveredUntil;

  bool keeps(HealthSpan row) {
    final covered = _coveredUntil;
    if (covered != null && covered > row.t0) {
      final span = row.t1 - row.t0;
      final overlap = min(covered, row.t1) - row.t0;
      if (span <= 0 || overlap > span * HealthOverlap.coveredRatio) {
        return false;
      }
    }
    if (covered == null || row.t1 > covered) _coveredUntil = row.t1;
    return true;
  }
}
