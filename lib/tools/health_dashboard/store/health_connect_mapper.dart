import 'package:health_connector/health_connector.dart' as hc;

import '../health_debug_origin.dart';
import 'health_metric_catalog.dart';
import 'health_rows.dart';
import 'health_schema.dart';

/// Turns a Health Connect record into typed rows.
///
/// Values are converted once, here, into the unit the metric catalog declares -
/// so nothing downstream parses, and no numeric ever becomes text. A record type
/// with no mapping yields an empty result and is skipped rather than stored in
/// some generic shape; the discovery page reports those as unmapped.
class HealthConnectMapper {
  const HealthConnectMapper();

  /// The writer a record is filed under.
  ///
  /// Everything that decides "who wrote this" - the mapper, discovery, the two
  /// exclusion checks - goes through here, so the debug generator's records get
  /// their own source everywhere rather than only in the tables.
  static String packageOf(hc.HealthRecord record) {
    final clientId = record.metadata.clientRecordId;
    if (clientId != null && clientId.startsWith(healthDebugClientIdPrefix)) {
      return healthDebugPackage;
    }
    return record.metadata.dataOrigin?.packageName ?? 'unknown';
  }

  HealthMappedRecord map(hc.HealthRecord record) {
    final package = packageOf(record);
    final points = _points(record);
    if (points.isNotEmpty) {
      return HealthMappedRecord(package: package, points: points);
    }
    final interval = _interval(record);
    if (interval != null) {
      return HealthMappedRecord(package: package, intervals: [interval]);
    }
    final session = _session(record);
    if (session != null) {
      return HealthMappedRecord(package: package, session: session);
    }
    final nutrition = _nutrition(record);
    if (nutrition != null) {
      return HealthMappedRecord(package: package, nutrition: nutrition);
    }
    return HealthMappedRecord(package: package);
  }

  List<HealthPointRow> _points(hc.HealthRecord record) => switch (record) {
    hc.HeartRateSeriesRecord(:final samples) => [
      for (final sample in samples)
        HealthPointRow(
          metric: HealthMetrics.heartRate,
          t: sample.time.millisecondsSinceEpoch,
          v: sample.rate.inPerMinute,
        ),
    ],
    hc.HeartRateRecord(:final time, :final rate) => [
      HealthPointRow(
        metric: HealthMetrics.heartRate,
        t: time.millisecondsSinceEpoch,
        v: rate.inPerMinute,
      ),
    ],
    hc.RestingHeartRateRecord(:final time, :final rate) => [
      HealthPointRow(
        metric: HealthMetrics.restingHeartRate,
        t: time.millisecondsSinceEpoch,
        v: rate.inPerMinute,
      ),
    ],
    hc.SpeedSeriesRecord(:final samples) => [
      for (final sample in samples)
        HealthPointRow(
          metric: HealthMetrics.speed,
          t: sample.time.millisecondsSinceEpoch,
          v: sample.speed.inKilometersPerHour,
        ),
    ],
    hc.PowerSeriesRecord(:final samples) => [
      for (final sample in samples)
        HealthPointRow(
          metric: HealthMetrics.power,
          t: sample.time.millisecondsSinceEpoch,
          v: sample.power.inWatts,
        ),
    ],
    hc.CyclingPedalingCadenceSeriesRecord(:final samples) => [
      for (final sample in samples)
        HealthPointRow(
          metric: HealthMetrics.cadence,
          t: sample.time.millisecondsSinceEpoch,
          v: sample.cadence.inPerMinute,
        ),
    ],
    hc.WeightRecord(:final time, :final weight) => [
      _instant(HealthMetrics.weight, time, weight.inKilograms),
    ],
    hc.BoneMassRecord(:final time, :final mass) => [
      _instant(HealthMetrics.boneMass, time, mass.inKilograms),
    ],
    hc.BodyWaterMassRecord(:final time, :final mass) => [
      _instant(HealthMetrics.bodyWaterMass, time, mass.inKilograms),
    ],
    hc.LeanBodyMassRecord(:final time, :final mass) => [
      _instant(HealthMetrics.leanBodyMass, time, mass.inKilograms),
    ],
    hc.BodyFatPercentageRecord(:final time, :final percentage) => [
      _instant(HealthMetrics.bodyFat, time, percentage.asWhole),
    ],
    hc.OxygenSaturationRecord(:final time, :final saturation) => [
      _instant(HealthMetrics.oxygenSaturation, time, saturation.asWhole),
    ],
    hc.HeartRateVariabilityRMSSDRecord(:final time, :final rmssd) => [
      _instant(HealthMetrics.hrvRmssd, time, rmssd.inMilliseconds),
    ],
    hc.RespiratoryRateRecord(:final time, :final rate) => [
      _instant(HealthMetrics.respiratoryRate, time, rate.inPerMinute),
    ],
    hc.BodyMassIndexRecord(:final time, :final bmi) => [
      _instant(HealthMetrics.bmi, time, bmi.value.toDouble()),
    ],
    hc.HeightRecord(:final time, :final height) => [
      _instant(HealthMetrics.height, time, height.inCentimeters),
    ],
    hc.BodyTemperatureRecord(:final time, :final temperature) => [
      _instant(HealthMetrics.bodyTemperature, time, temperature.inCelsius),
    ],
    hc.BloodGlucoseRecord(:final time, :final glucoseLevel) => [
      _instant(
        HealthMetrics.bloodGlucose,
        time,
        glucoseLevel.inMillimolesPerLiter,
      ),
    ],
    // The one paired metric: both halves belong to a single reading, so they
    // share a row rather than becoming two metrics that could drift apart.
    hc.BloodPressureRecord(:final time, :final systolic, :final diastolic) => [
      HealthPointRow(
        metric: HealthMetrics.bloodPressure,
        t: time.millisecondsSinceEpoch,
        v: systolic.inMillimetersOfMercury,
        v2: diastolic.inMillimetersOfMercury,
      ),
    ],
    _ => const [],
  };

  static HealthPointRow _instant(String metric, DateTime time, double value) =>
      HealthPointRow(metric: metric, t: time.millisecondsSinceEpoch, v: value);

  HealthIntervalRow? _interval(hc.HealthRecord record) => switch (record) {
    hc.StepsRecord(:final count) => _range(
      record,
      HealthMetrics.steps,
      count.value.toDouble(),
    ),
    hc.DistanceRecord(:final distance) => _range(
      record,
      HealthMetrics.distance,
      distance.inKilometers,
    ),
    hc.ActiveEnergyBurnedRecord(:final energy) => _range(
      record,
      HealthMetrics.activeEnergy,
      energy.inKilocalories,
    ),
    hc.TotalEnergyBurnedRecord(:final energy) => _range(
      record,
      HealthMetrics.totalEnergy,
      energy.inKilocalories,
    ),
    hc.FloorsClimbedRecord(:final count) => _range(
      record,
      HealthMetrics.floors,
      count.value.toDouble(),
    ),
    hc.ElevationGainedRecord(:final elevation) => _range(
      record,
      HealthMetrics.elevationGained,
      elevation.inMeters,
    ),
    // No ExerciseTime/MoveTime/StandTime: those are Apple Health types
    // (`apple_exercise_time` and friends) and are absent from
    // `healthConnectDataTypes`, so cases for them could never fire here.
    hc.HydrationRecord(:final volume) => _range(
      record,
      HealthMetrics.hydration,
      volume.inLiters,
    ),
    hc.WheelchairPushesRecord(:final count) => _range(
      record,
      HealthMetrics.wheelchairPushes,
      count.value.toDouble(),
    ),
    _ => null,
  };

  static HealthIntervalRow? _range(
    hc.HealthRecord record,
    String metric,
    double value,
  ) {
    if (record is! hc.IntervalHealthRecord) return null;
    return HealthIntervalRow(
      metric: metric,
      t0: record.startTime.millisecondsSinceEpoch,
      t1: record.endTime.millisecondsSinceEpoch,
      v: value,
      origin: record.id.value,
    );
  }

  HealthSessionRow? _session(hc.HealthRecord record) => switch (record) {
    hc.ExerciseSessionRecord(
      :final startTime,
      :final endTime,
      :final exerciseType,
      :final title,
      :final notes,
      :final lapEvents,
    ) =>
      HealthSessionRow(
        kind: HealthSchema.sessionKindExercise,
        activity: exerciseType.name,
        title: title,
        notes: notes,
        t0: startTime.millisecondsSinceEpoch,
        t1: endTime.millisecondsSinceEpoch,
        origin: record.id.value,
        clientId: record.metadata.clientRecordId,
        parts: [
          for (final lap in lapEvents)
            HealthSessionPartRow(
              kind: HealthSchema.partKindLap,
              t0: lap.startTime.millisecondsSinceEpoch,
              t1: lap.endTime.millisecondsSinceEpoch,
              v: lap.distance?.inKilometers,
            ),
        ],
      ),
    hc.SleepSessionRecord(
      :final startTime,
      :final endTime,
      :final title,
      :final samples,
    ) =>
      HealthSessionRow(
        kind: HealthSchema.sessionKindSleep,
        title: title,
        t0: startTime.millisecondsSinceEpoch,
        t1: endTime.millisecondsSinceEpoch,
        origin: record.id.value,
        clientId: record.metadata.clientRecordId,
        asleepMin: _asleepMinutes(samples),
        parts: [
          for (final stage in samples)
            HealthSessionPartRow(
              kind: HealthSchema.partKindSleepStage,
              part: stage.stageType.name,
              t0: stage.startTime.millisecondsSinceEpoch,
              t1: stage.endTime.millisecondsSinceEpoch,
            ),
        ],
      ),
    _ => null,
  };

  HealthNutritionRow? _nutrition(hc.HealthRecord record) => switch (record) {
    hc.NutritionRecord(
      :final startTime,
      :final endTime,
      :final foodName,
      :final mealType,
      :final energy,
      :final protein,
      :final totalCarbohydrate,
      :final totalFat,
    ) =>
      HealthNutritionRow(
        t0: startTime.millisecondsSinceEpoch,
        t1: endTime.millisecondsSinceEpoch,
        origin: record.id.value,
        clientId: record.metadata.clientRecordId,
        foodName: foodName,
        mealType: mealType.name,
        energyKcal: energy?.inKilocalories,
        proteinG: protein?.inGrams,
        carbohydrateG: totalCarbohydrate?.inGrams,
        fatG: totalFat?.inGrams,
      ),
    _ => null,
  };

  /// Time actually asleep, computed here because the stage list is in hand.
  /// A session's span includes time awake in bed, so the span is not the
  /// sleep duration. Falls back to null when a writer supplies no stages,
  /// which keeps "no data" distinct from "zero minutes asleep".
  static int? _asleepMinutes(List<hc.SleepStageSample> stages) {
    if (stages.isEmpty) return null;
    const awake = {'awake', 'awakeInBed', 'outOfBed', 'unknown'};
    var millis = 0;
    for (final stage in stages) {
      if (awake.contains(stage.stageType.name)) continue;
      millis += stage.endTime.difference(stage.startTime).inMilliseconds;
    }
    return millis ~/ Duration.millisecondsPerMinute;
  }
}
