import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import '../health_record.dart';
import '../health_record_values.dart';
import 'health_metric_catalog.dart';
import 'health_metric_series.dart';
import 'health_schema.dart';
import 'health_store.dart';

/// Reads the typed store and projects it into [HealthRecord] for the dashboard.
///
/// The typed tables are the only storage. This layer exists so the widgets keep
/// a single record shape to render, while the numbers behind it come from real
/// columns instead of a JSON blob. Type strings are unchanged from the previous
/// model, so nothing downstream had to be rewritten.
///
/// Aggregates never touch the dense tables - they read `health_daily`.
class HealthQueries {
  HealthQueries._();

  static final HealthQueries instance = HealthQueries._();

  /// Dashboard type string for each metric that the UI surfaces directly.
  static const metricTypes = <String, String>{
    HealthMetrics.weight: 'body.weight',
    HealthMetrics.restingHeartRate: 'heart.resting',
    HealthMetrics.heartRate: 'heart.rate',
    HealthMetrics.steps: 'activity.steps',
    HealthMetrics.hrvRmssd: 'health.heart_rate_variability_rmssd',
    HealthMetrics.oxygenSaturation: 'health.oxygen_saturation',
    HealthMetrics.respiratoryRate: 'health.respiratory_rate',
    HealthMetrics.bodyFat: 'health.body_fat_percentage',
    HealthMetrics.bmi: 'health.body_mass_index',
    HealthMetrics.height: 'health.height',
    HealthMetrics.bloodGlucose: 'health.blood_glucose',
    HealthMetrics.bodyTemperature: 'health.body_temperature',
    HealthMetrics.bloodPressure: 'health.blood_pressure',
    HealthMetrics.boneMass: 'health.bone_mass',
    HealthMetrics.bodyWaterMass: 'health.body_water_mass',
    HealthMetrics.leanBodyMass: 'health.lean_body_mass',
    HealthMetrics.distance: 'health.distance',
    HealthMetrics.activeEnergy: 'health.active_calories',
    HealthMetrics.totalEnergy: 'health.total_calories',
    HealthMetrics.floors: 'health.floors_climbed',
    HealthMetrics.elevationGained: 'health.elevation_gained',
    HealthMetrics.hydration: 'health.hydration',
    HealthMetrics.speed: 'health.speed',
    HealthMetrics.cadence: 'health.cadence',
    HealthMetrics.power: 'health.power',
    HealthMetrics.wheelchairPushes: 'health.wheelchair_pushes',
  };

  static final _typeToMetric = {
    for (final entry in metricTypes.entries) entry.value: entry.key,
  };

  static const workoutType = 'workout.health_connect';
  static const sleepType = 'sleep.session';

  /// The value key each metric's number is published under, kept identical to
  /// the keys the widgets already read.
  static const _valueKeys = <String, String>{
    HealthMetrics.weight: 'kilograms',
    HealthMetrics.restingHeartRate: 'bpm',
    HealthMetrics.steps: 'count',
    HealthMetrics.hrvRmssd: 'rmssdMs',
    HealthMetrics.oxygenSaturation: 'percent',
    HealthMetrics.respiratoryRate: 'respiratoryRate',
    HealthMetrics.bodyFat: 'percent',
    HealthMetrics.bmi: 'bmi',
    HealthMetrics.height: 'centimeters',
    HealthMetrics.distance: 'distanceKm',
    HealthMetrics.activeEnergy: 'calories',
    HealthMetrics.totalEnergy: 'calories',
    HealthMetrics.floors: 'floors',
    HealthMetrics.hydration: 'liters',
    HealthMetrics.boneMass: 'kilograms',
    HealthMetrics.bodyWaterMass: 'kilograms',
    HealthMetrics.leanBodyMass: 'kilograms',
  };

  static String valueKeyFor(String metric) => _valueKeys[metric] ?? 'value';

  /// The catalog metric a dashboard type string stands for, or null for the
  /// session types, which are not catalog metrics.
  static String? metricForType(String type) => _typeToMetric[type];

  /// Types the dashboard renders in its week window and latest-value cards.
  static const dashboardTypes = [
    'body.weight',
    'heart.resting',
    sleepType,
    workoutType,
    'health.heart_rate_variability_rmssd',
    'health.oxygen_saturation',
    'health.respiratory_rate',
    'health.body_fat_percentage',
  ];

  static const _latestTypes = [
    'body.weight',
    'heart.resting',
    sleepType,
    'health.heart_rate_variability_rmssd',
    'health.oxygen_saturation',
    'health.respiratory_rate',
    'health.body_fat_percentage',
  ];

  HealthStore get _store => HealthStore.instance;

  // --- record projections ---------------------------------------------------

  HealthRecord _pointRecord(String metric, HealthPoint point) {
    final type = metricTypes[metric] ?? 'health.$metric';
    final key = valueKeyFor(metric);
    return HealthRecord(
      id: 'p:$metric:${point.t}:${point.v}',
      source: HealthSource.healthConnect,
      sourceRecordId: '${point.t}',
      type: type,
      startTime: point.t,
      endTime: point.t,
      value: {
        key: point.v,
        if (point.v2 != null) 'diastolicMmhg': point.v2,
        if (metric == HealthMetrics.bloodPressure) 'systolicMmhg': point.v,
        if (metric == HealthMetrics.heartRate) ...{
          'averageBpm': point.v,
          'minimumBpm': point.v,
          'maximumBpm': point.v,
          'samples': [
            {'time': point.t, 'bpm': point.v},
          ],
        },
      },
      sourceName: point.package,
      aggregateIncluded: true,
      createdAt: point.t,
      updatedAt: point.t,
      deleted: false,
      synced: false,
    );
  }

  HealthRecord _intervalRecord(String metric, HealthInterval interval) {
    final type = metricTypes[metric] ?? 'health.$metric';
    return HealthRecord(
      id: 'i:$metric:${interval.t0}:${interval.v}',
      source: HealthSource.healthConnect,
      sourceRecordId: '${interval.t0}',
      type: type,
      startTime: interval.t0,
      endTime: interval.t1,
      value: {valueKeyFor(metric): interval.v},
      sourceName: interval.package,
      aggregateIncluded: true,
      createdAt: interval.t0,
      updatedAt: interval.t1,
      deleted: false,
      synced: false,
    );
  }

  /// Sessions carry their stages or laps, and for a workout the summary columns
  /// filled in after import. Dense curves are fetched separately by the
  /// drilldown, so a list never pays for them.
  Future<HealthRecord> _sessionRecord(
    HealthSession session, {
    bool withParts = true,
  }) async {
    final isSleep = session.kind == HealthSchema.sessionKindSleep;
    final parts = withParts
        ? await _store.sessionParts(session.id)
        : const <HealthSessionPart>[];
    return HealthRecord(
      id: 's:${session.id}',
      source: HealthSource.healthConnect,
      sourceRecordId: session.origin,
      type: isSleep ? sleepType : workoutType,
      startTime: session.t0,
      endTime: session.t1,
      value: {
        if (session.title != null) 'title': session.title,
        if (session.notes != null) 'notes': session.notes,
        if (session.clientId != null) 'clientRecordId': session.clientId,
        if (isSleep) ...{
          // The writer's own asleep figure, which the quality check prefers over
          // the session span when no stages were stored.
          if (session.asleepMin != null) 'asleepMinutes': session.asleepMin,
          'stages': [
            for (final part in parts)
              {'startTime': part.t0, 'endTime': part.t1, 'type': part.part},
          ],
        } else ...{
          'exerciseType': session.activity,
          'distanceKm': session.distanceKm ?? 0,
          'calories': session.calories ?? 0,
          if (session.steps != null) 'count': session.steps,
          'averageHeartRate': session.avgHr,
          'maximumHeartRate': session.maxHr,
          'averageSpeedKmh': session.avgSpeed,
          'maximumSpeedKmh': session.maxSpeed,
          'laps': [
            for (final part in parts)
              {'startTime': part.t0, 'endTime': part.t1, 'distanceKm': part.v},
          ],
        },
      },
      sourceName: session.package,
      aggregateIncluded: true,
      createdAt: session.t0,
      updatedAt: session.t1,
      deleted: false,
      synced: false,
    );
  }

  // --- dashboard reads ------------------------------------------------------

  Future<List<HealthRecord>> dashboardRecords({
    required DateTime start,
    required DateTime end,
  }) async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final from = start.millisecondsSinceEpoch;
    final to = end.millisecondsSinceEpoch;
    final records = <HealthRecord>[];
    for (final session in await _store.sessions(from: from, to: to)) {
      records.add(await _sessionRecord(session));
    }
    for (final type in _latestTypes) {
      if (type == sleepType) continue;
      final metric = _typeToMetric[type];
      if (metric == null) continue;
      for (final point in await _store.pointsInRange(
        metric: metric,
        from: from,
        to: to,
      )) {
        records.add(_pointRecord(metric, point));
      }
    }
    if (kDebugMode) {
      debugLog(
        '[HealthQueries] Week window: ${records.length} records in '
        '${stopwatch!.elapsedMilliseconds}ms',
      );
    }
    return records;
  }

  /// Newest value per metric card. Each one is a primary-key seek, so this is
  /// cheap no matter how much history exists.
  Future<List<HealthRecord>> latestDashboardRecords() async {
    final records = <HealthRecord>[];
    for (final type in _latestTypes) {
      if (type == sleepType) {
        final sleep = await _store.sessions(
          kind: HealthSchema.sessionKindSleep,
          limit: 14,
        );
        for (final session in sleep) {
          records.add(await _sessionRecord(session));
        }
        continue;
      }
      final metric = _typeToMetric[type];
      if (metric == null) continue;
      final point = await _store.latestPoint(metric);
      if (point != null) records.add(_pointRecord(metric, point));
    }
    return records;
  }

  Future<List<HealthRecord>> recordsOnDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return dashboardRecords(start: start, end: end);
  }

  Future<List<HealthRecord>> recordsForDay({
    required String type,
    required DateTime day,
  }) async {
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(
      day.year,
      day.month,
      day.day + 1,
    ).millisecondsSinceEpoch;
    if (type == sleepType || type == workoutType) {
      final kind = type == sleepType
          ? HealthSchema.sessionKindSleep
          : HealthSchema.sessionKindExercise;
      final sessions = await _store.sessions(kind: kind, from: start, to: end);
      return [for (final session in sessions) await _sessionRecord(session)];
    }
    final metric = _typeToMetric[type];
    if (metric == null) return const [];
    final spec = HealthMetrics.spec(metric);
    if (spec?.shape == HealthMetricShape.interval) {
      final rows = await _store.intervalsInRange(
        metric: metric,
        from: start,
        to: end,
      );
      return [for (final row in rows) _intervalRecord(metric, row)];
    }
    final points = await _store.pointsInRange(
      metric: metric,
      from: start,
      to: end,
    );
    return [for (final point in points) _pointRecord(metric, point)];
  }

  /// Per-day figures for one metric, the single source a drilldown reads.
  ///
  /// Metrics come off `health_daily`, which already picked one source per day,
  /// so a week costs seven rollup rows. Sessions have no rollup and are summed
  /// per day from the session table instead.
  Future<HealthMetricSeries> metricSeries({
    required String type,
    required String valueKey,
    required List<DateTime> days,
    required bool sum,
  }) async {
    if (days.isEmpty) return HealthMetricSeries(days: const [], sum: sum);
    final metric = _typeToMetric[type];
    if (metric == null) {
      return HealthMetricSeries(
        days: [
          for (final day in days) await _sessionDay(type, valueKey, day, sum),
        ],
        sum: sum,
      );
    }
    final rollups = await _store.dailyRange(
      metric: metric,
      fromDay: HealthStore.dayKey(days.first.millisecondsSinceEpoch),
      toDay: HealthStore.dayKey(days.last.millisecondsSinceEpoch),
    );
    final byDay = {for (final row in rollups) row.day: row};
    return HealthMetricSeries(
      days: [
        for (final day in days)
          _rollupDay(
            day,
            byDay[HealthStore.dayKey(day.millisecondsSinceEpoch)],
            sum,
          ),
      ],
      sum: sum,
    );
  }

  static HealthMetricDay _rollupDay(
    DateTime day,
    HealthDailyValue? rollup,
    bool sum,
  ) {
    if (rollup == null || rollup.n == 0) return HealthMetricDay(day: day);
    return HealthMetricDay(
      day: day,
      value: sum ? rollup.total : (rollup.avg ?? rollup.total),
      lo: rollup.lo,
      hi: rollup.hi,
      count: rollup.n,
    );
  }

  Future<HealthMetricDay> _sessionDay(
    String type,
    String valueKey,
    DateTime day,
    bool sum,
  ) async {
    final records = await recordsForDay(type: type, day: day);
    final values = [
      for (final record in records)
        if (type != sleepType || !healthRecordIsNap(record))
          ...<double?>[healthRecordValue(record, valueKey)].whereType<double>(),
    ];
    if (values.isEmpty) return HealthMetricDay(day: day);
    final total = values.reduce((a, b) => a + b);
    return HealthMetricDay(
      day: day,
      // A night and its naps are separate sessions; the night is the figure.
      value: type == sleepType
          ? values.reduce(math.max)
          : (sum ? total : total / values.length),
      lo: values.reduce(math.min),
      hi: values.reduce(math.max),
      count: values.length,
    );
  }

  /// Paged browse for the all-data and history screens.
  Future<List<HealthRecord>> recordsPage({
    String? typePrefix,
    String? type,
    int offset = 0,
    int limit = 100,
  }) async {
    if (type == sleepType || type == workoutType) {
      final kind = type == sleepType
          ? HealthSchema.sessionKindSleep
          : HealthSchema.sessionKindExercise;
      final sessions = await _store.sessions(
        kind: kind,
        limit: limit,
        offset: offset,
      );
      return [
        for (final session in sessions)
          await _sessionRecord(session, withParts: false),
      ];
    }
    if (type != null) {
      final metric = _typeToMetric[type];
      if (metric == null) return const [];
      return _metricPage(metric, offset: offset, limit: limit);
    }
    // No type given: walk the metrics in catalog order so paging is stable.
    final records = <HealthRecord>[];
    var skip = offset;
    for (final entry in metricTypes.entries) {
      if (typePrefix != null && !entry.value.startsWith(typePrefix)) continue;
      final available = await _store.metricCount(entry.key);
      if (skip >= available) {
        skip -= available;
        continue;
      }
      records.addAll(
        await _metricPage(
          entry.key,
          offset: skip,
          limit: limit - records.length,
        ),
      );
      skip = 0;
      if (records.length >= limit) break;
    }
    return records;
  }

  Future<List<HealthRecord>> _metricPage(
    String metric, {
    required int offset,
    required int limit,
  }) async {
    final spec = HealthMetrics.spec(metric);
    if (spec?.shape == HealthMetricShape.interval) {
      final rows = await _store.intervalPage(
        metric: metric,
        offset: offset,
        limit: limit,
      );
      return [for (final row in rows) _intervalRecord(metric, row)];
    }
    final rows = await _store.pointPage(
      metric: metric,
      offset: offset,
      limit: limit,
    );
    return [for (final row in rows) _pointRecord(metric, row)];
  }

  // --- aggregates, all off health_daily ------------------------------------

  Future<Map<String, num>> allTimeWorkoutSummary() => _store.workoutSummary();

  Future<int> allTimeSteps() async =>
      (await _store.allTimeTotal(HealthMetrics.steps)).round();

  Future<Map<String, int>> dailyStepTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    final days = await _store.dailyRange(
      metric: HealthMetrics.steps,
      fromDay: HealthStore.dayKey(start.millisecondsSinceEpoch),
      toDay: HealthStore.dayKey(end.millisecondsSinceEpoch),
    );
    return {
      for (final day in days) _dayKeyString(day.day): (day.total ?? 0).round(),
    };
  }

  /// Newest dense heart rate sample. It is not in [_latestTypes] on purpose:
  /// that list is also the week window, and a week of samples is tens of
  /// thousands of rows the dashboard has no use for.
  Future<double?> latestHeartRate() async =>
      (await _store.latestPoint(HealthMetrics.heartRate))?.v;

  Future<Map<String, double>> dailyHeartRateAverages({
    required DateTime start,
    required DateTime end,
  }) async {
    final days = await _store.dailyRange(
      metric: HealthMetrics.heartRate,
      fromDay: HealthStore.dayKey(start.millisecondsSinceEpoch),
      toDay: HealthStore.dayKey(end.millisecondsSinceEpoch),
    );
    return {
      for (final day in days)
        if (day.avg != null) _dayKeyString(day.day): day.avg!,
    };
  }

  static String _dayKeyString(int dayKey) {
    final date = DateTime.fromMillisecondsSinceEpoch(dayKey);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
