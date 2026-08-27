import 'health_metric_catalog.dart';
import 'health_schema.dart';

/// What the store hands back. The inbound direction — what an importer offers
/// it — lives in `health_rows.dart`.

/// What a backup file says about itself, read from its marker table.
class HealthBackupInfo {
  final int schemaVersion;
  final DateTime? exportedAt;

  const HealthBackupInfo({required this.schemaVersion, this.exportedAt});

  /// A file from a newer build. Its tables may hold columns this schema cannot
  /// place, so restoring it would silently drop data.
  bool get isNewerThanApp => schemaVersion > HealthSchema.version;
}

class HealthBackupTooNewException implements Exception {
  final int schemaVersion;

  const HealthBackupTooNewException(this.schemaVersion);

  @override
  String toString() =>
      'Backup schema v$schemaVersion is newer than v${HealthSchema.version}.';
}

/// A day's reduced value for one metric, straight out of `health_daily`.
class HealthDailyValue {
  final int day;
  final double? total;
  final double? avg;
  final double? lo;
  final double? hi;
  final int n;

  const HealthDailyValue({
    required this.day,
    required this.total,
    required this.avg,
    required this.lo,
    required this.hi,
    required this.n,
  });

  /// The number this metric is meant to be shown as.
  double? valueFor(HealthAggregation aggregation) => switch (aggregation) {
    HealthAggregation.total => total,
    HealthAggregation.average || HealthAggregation.latest => avg,
  };
}

class HealthSession {
  final int id;
  final int kind;
  final String? activity;
  final String? title;
  final String? notes;
  final int t0;
  final int t1;
  final String? package;

  /// The Health Connect record id, and only meaningful on the device that
  /// imported it. Null for a session that arrived through backend sync.
  final String? origin;
  final String? clientId;
  final double? distanceKm;
  final double? calories;
  final int? steps;
  final double? avgHr;
  final double? maxHr;
  final double? avgSpeed;
  final double? maxSpeed;
  final int? asleepMin;

  const HealthSession({
    required this.id,
    required this.kind,
    required this.t0,
    required this.t1,
    this.origin,
    this.activity,
    this.title,
    this.notes,
    this.package,
    this.clientId,
    this.distanceKm,
    this.calories,
    this.steps,
    this.avgHr,
    this.maxHr,
    this.avgSpeed,
    this.maxSpeed,
    this.asleepMin,
  });

  int get durationSeconds => (t1 - t0) ~/ 1000;
}

class HealthSessionPart {
  final int kind;
  final String? part;
  final int? t0;
  final int? t1;
  final double? v;

  const HealthSessionPart({
    required this.kind,
    this.part,
    this.t0,
    this.t1,
    this.v,
  });
}

/// A single measurement read back for a chart.
class HealthPoint {
  final int t;
  final double v;
  final double? v2;

  /// Writing app, so a list can show which source a measurement came from.
  final String? package;

  const HealthPoint(this.t, this.v, [this.v2, this.package]);
}

/// An interval value read back for a list or chart.
class HealthInterval {
  final int t0;
  final int t1;
  final double v;
  final String? package;

  const HealthInterval(this.t0, this.t1, this.v, [this.package]);
}

class HealthNutrition {
  final int id;
  final int t0;
  final int t1;
  final String? package;
  final String? origin;
  final String? clientId;
  final String? foodName;
  final String? mealType;
  final double? energyKcal;
  final double? proteinG;
  final double? carbohydrateG;
  final double? fatG;

  const HealthNutrition({
    required this.id,
    required this.t0,
    required this.t1,
    this.package,
    this.origin,
    this.clientId,
    this.foodName,
    this.mealType,
    this.energyKcal,
    this.proteinG,
    this.carbohydrateG,
    this.fatG,
  });
}

class HealthDiscoveredApp {
  final int appId;
  final String package;
  final bool enabled;
  final int count;
  final int? lastSeen;

  const HealthDiscoveredApp({
    required this.appId,
    required this.package,
    required this.enabled,
    required this.count,
    this.lastSeen,
  });
}

/// A writer as the global app list shows it: switched on or off everywhere, and
/// where it sits in the priority order.
class HealthAppState {
  final int appId;
  final String package;
  final bool enabled;
  final int prio;

  /// How many data types this writer is still selected for.
  final int typeCount;

  const HealthAppState({
    required this.appId,
    required this.package,
    required this.enabled,
    required this.prio,
    required this.typeCount,
  });

  HealthAppState withEnabled(bool value) => HealthAppState(
    appId: appId,
    package: package,
    enabled: value,
    prio: prio,
    typeCount: typeCount,
  );
}

class HealthTypeState {
  final String type;
  final bool enabled;
  final bool historyDone;
  final int count;

  /// Window an interrupted full import was covering, null when none is pending.
  final int? rangeStart;
  final int? rangeEnd;

  const HealthTypeState({
    required this.type,
    required this.enabled,
    required this.historyDone,
    required this.count,
    this.rangeStart,
    this.rangeEnd,
  });

  factory HealthTypeState.fromMap(Map<String, Object?> map) => HealthTypeState(
    type: map['type'] as String? ?? '',
    enabled: (map['enabled'] as int? ?? 0) == 1,
    historyDone: (map['history_done'] as int? ?? 0) == 1,
    count: (map['n'] as num?)?.toInt() ?? 0,
    rangeStart: (map['range_start'] as num?)?.toInt(),
    rangeEnd: (map['range_end'] as num?)?.toInt(),
  );
}

/// What a `HealthStore.pruneUnused` pass removed.
class HealthPruneResult {
  final int rows;
  final int text;

  const HealthPruneResult({required this.rows, required this.text});

  bool get isEmpty => rows == 0 && text == 0;
}

/// One manifest row: what the backend is owed for a (UTC day, writer) pair.
///
/// [id] is the sync record id the engine sees, and carries the writer's package
/// rather than its interned id - one device's `app = 3` is another's `app = 7`.
class HealthChunkMeta {
  final int day;
  final String package;
  final int updatedAt;
  final bool dirty;
  final bool deleted;

  const HealthChunkMeta({
    required this.day,
    required this.package,
    required this.updatedAt,
    required this.dirty,
    required this.deleted,
  });

  String get id => 'd$day:$package';

  /// Null when [id] is not a chunk id this build wrote, which is what a record
  /// from a newer schema looks like.
  static (int day, String package)? parseId(String id) {
    if (!id.startsWith('d')) return null;
    final separator = id.indexOf(':');
    if (separator < 2) return null;
    final day = int.tryParse(id.substring(1, separator));
    if (day == null) return null;
    final package = id.substring(separator + 1);
    return package.isEmpty ? null : (day, package);
  }
}
