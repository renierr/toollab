import 'health_schema.dart';

/// One measurement at an instant, destined for `health_point`.
class HealthPointRow {
  final String metric;
  final int t;
  final double v;

  /// Only the paired metrics use this - diastolic against systolic.
  final double? v2;

  const HealthPointRow({
    required this.metric,
    required this.t,
    required this.v,
    this.v2,
  });
}

/// One value spanning a range, destined for `health_interval`.
class HealthIntervalRow {
  final String metric;
  final int t0;
  final int t1;
  final double v;
  final String? origin;

  const HealthIntervalRow({
    required this.metric,
    required this.t0,
    required this.t1,
    required this.v,
    this.origin,
  });
}

class HealthSessionPartRow {
  /// [HealthSchema.partKindSleepStage] or [HealthSchema.partKindLap].
  final int kind;

  /// Interned label: the sleep stage name, or null for a lap.
  final String? part;
  final int? t0;
  final int? t1;
  final double? v;

  const HealthSessionPartRow({
    required this.kind,
    this.part,
    this.t0,
    this.t1,
    this.v,
  });
}

/// An exercise or sleep session with its summary already reduced, so a workout
/// list never reaches into the dense tables.
class HealthSessionRow {
  final int kind;
  final String? activity;
  final String? title;
  final String? notes;
  final int t0;
  final int t1;

  /// Health Connect record id. Null for a session rebuilt from a sync chunk:
  /// the sender's id names a record in the sender's Health Connect, not ours.
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
  final List<HealthSessionPartRow> parts;

  const HealthSessionRow({
    required this.kind,
    required this.t0,
    required this.t1,
    this.origin,
    this.activity,
    this.title,
    this.notes,
    this.clientId,
    this.distanceKm,
    this.calories,
    this.steps,
    this.avgHr,
    this.maxHr,
    this.avgSpeed,
    this.maxSpeed,
    this.asleepMin,
    this.parts = const [],
  });
}

/// One meal with its nutrients intact. Nutrition must not be split into metric
/// rows: the meal name is what makes calories and macros useful together.
class HealthNutritionRow {
  final int t0;
  final int t1;
  final String? origin;
  final String? clientId;
  final String? foodName;
  final String? mealType;
  final double? energyKcal;
  final double? proteinG;
  final double? carbohydrateG;
  final double? fatG;

  const HealthNutritionRow({
    required this.t0,
    required this.t1,
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

/// Everything one Health Connect record turned into. A dense series record
/// yields many points; a workout yields a session plus its parts.
class HealthMappedRecord {
  /// Writing app package, interned to `health_app`.
  final String package;
  final List<HealthPointRow> points;
  final List<HealthIntervalRow> intervals;
  final HealthSessionRow? session;
  final HealthNutritionRow? nutrition;

  const HealthMappedRecord({
    required this.package,
    this.points = const [],
    this.intervals = const [],
    this.session,
    this.nutrition,
  });

  bool get isEmpty =>
      points.isEmpty &&
      intervals.isEmpty &&
      session == null &&
      nutrition == null;
}
