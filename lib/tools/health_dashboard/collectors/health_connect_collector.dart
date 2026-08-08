import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;
// ignore: implementation_imports
import 'package:health_connector_core/src/models/health_data_types/health_data_type_capabilities/readable_health_data_type.dart'
    as core;
// ignore: implementation_imports
import 'package:health_connector_core/src/utils/health_record_data_type_extension.dart';

import '../health_record.dart';
import 'health_data_collector.dart';

class HealthConnectCollector implements HealthDataCollector {
  @override
  HealthSource get source => HealthSource.healthConnect;

  Future<void> requestAccess() async {
    if (!Platform.isAndroid) return;
    final connector = await hc.HealthConnector.create();
    await connector.requestPermissions([
      for (final type in hc.HealthDataType.healthConnectDataTypes)
        if (type is core.ReadableHealthDataType)
          (type as core.ReadableHealthDataType).readPermission,
      hc.HealthPlatformFeature.readHealthDataHistory.permission,
    ]);
  }

  @override
  Future<List<HealthRecord>> collect({DateTime? start}) async {
    if (!Platform.isAndroid) return [];
    final connector = await hc.HealthConnector.create();
    final end = DateTime.now();
    final importStart =
        start ?? DateTime.now().subtract(const Duration(days: 90));
    final records = <HealthRecord>[];

    // Persist every readable record so data that has no dedicated dashboard yet
    // remains available in All Health Data. Rich converters below replace these.
    records.addAll(await _allRecords(connector, importStart, end));

    final steps = await _safeReadRecords<hc.StepsRecord>(
      () => connector.readRecords(
        hc.HealthDataType.steps.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    records.addAll(steps.map(_steps));

    final weights = await _safeReadRecords<hc.WeightRecord>(
      () => connector.readRecords(
        hc.HealthDataType.weight.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    records.addAll(weights.map(_weight));

    final heartRates = await _safeReadRecords<hc.HeartRateSeriesRecord>(
      () => connector.readRecords(
        hc.HealthDataType.heartRateSeries.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    records.addAll(heartRates.map(_heartRate));

    final instantHeartRates = await _safeReadRecords<hc.HeartRateRecord>(
      () => connector.readRecords(
        hc.HealthDataType.heartRate.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    records.addAll(instantHeartRates.map(_instantHeartRate));

    final restingRates = await _safeReadRecords<hc.RestingHeartRateRecord>(
      () => connector.readRecords(
        hc.HealthDataType.restingHeartRate.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    records.addAll(restingRates.map(_restingHeartRate));

    final sleep = await _safeReadRecords<hc.SleepSessionRecord>(
      () => connector.readRecords(
        hc.HealthDataType.sleepSession.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    records.addAll(sleep.map(_sleep));

    final workouts = await _safeReadRecords<hc.ExerciseSessionRecord>(
      () => connector.readRecords(
        hc.HealthDataType.exerciseSession.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    final distances = await _safeReadRecords<hc.DistanceRecord>(
      () => connector.readRecords(
        hc.HealthDataType.distance.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    final activeEnergy = await _safeReadRecords<hc.ActiveEnergyBurnedRecord>(
      () => connector.readRecords(
        hc.HealthDataType.activeEnergyBurned.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    final speeds = await _safeReadRecords<hc.SpeedSeriesRecord>(
      () => connector.readRecords(
        hc.HealthDataType.speedSeries.readInTimeRange(
          startTime: importStart,
          endTime: end,
        ),
      ),
    );
    final usedMetricIds = <String>{};
    records.addAll(
      workouts.map(
        (workout) => _workout(
          workout,
          heartRates,
          distances,
          activeEnergy,
          speeds,
          usedMetricIds,
        ),
      ),
    );
    return records;
  }

  Future<List<T>> _safeReadRecords<T>(Future<dynamic> Function() call) async {
    try {
      final response = await call();
      return (response.records as List).cast<T>();
    } catch (_) {
      return <T>[];
    }
  }

  Future<List<HealthRecord>> _allRecords(
    hc.HealthConnector connector,
    DateTime start,
    DateTime end,
  ) async {
    final records = <HealthRecord>[];
    for (final type in hc.HealthDataType.healthConnectDataTypes) {
      if (type is! core.ReadableInTimeRangeHealthDataType) continue;
      try {
        final readable = type as core.ReadableInTimeRangeHealthDataType;
        final response = await connector.readRecords(
          readable.readInTimeRange(startTime: start, endTime: end),
        );
        records.addAll(response.records.map(_genericRecord));
      } catch (_) {
        // Health Connect can reject unavailable or unsupported data types.
      }
    }
    return records;
  }

  HealthRecord _genericRecord(hc.HealthRecord record) {
    final (startTime, endTime) = switch (record) {
      hc.InstantHealthRecord(:final time) => (time, time),
      hc.IntervalHealthRecord(:final startTime, :final endTime) => (
        startTime,
        endTime,
      ),
    };
    return _record(
      record: record,
      type: 'health.${record.dataType.id}',
      startTime: startTime,
      endTime: endTime,
      value: {
        'dataType': record.dataType.id,
        'category': record.category.name,
        'recordType': record.runtimeType.toString(),
        ..._genericValues(record),
      },
    );
  }

  Map<String, dynamic> _genericValues(hc.HealthRecord record) =>
      switch (record) {
        hc.FloorsClimbedRecord(:final count) => {'floors': count.value},
        hc.ExerciseTimeRecord(:final exerciseTime) => {
          'minutes': exerciseTime.inMinutes,
        },
        hc.MoveTimeRecord(:final moveTime) => {'minutes': moveTime.inMinutes},
        hc.StandTimeRecord(:final standTime) => {
          'minutes': standTime.inMinutes,
        },
        hc.BloodPressureRecord(:final systolic, :final diastolic) => {
          'systolicMmhg': systolic.inMillimetersOfMercury,
          'diastolicMmhg': diastolic.inMillimetersOfMercury,
        },
        hc.OxygenSaturationRecord(:final saturation) => {
          'percent': saturation.asWhole,
        },
        hc.BodyFatPercentageRecord(:final percentage) => {
          'percent': percentage.asWhole,
        },
        hc.BodyMassIndexRecord(:final bmi) => {'bmi': bmi.value},
        hc.HeightRecord(:final height) => {'centimeters': height.inCentimeters},
        hc.HydrationRecord(:final volume) => {'liters': volume.inLiters},
        _ => const {},
      };

  HealthRecord _steps(hc.StepsRecord record) => _record(
    record: record,
    type: 'activity.steps',
    startTime: record.startTime,
    endTime: record.endTime,
    value: {'count': record.count.value},
  );

  HealthRecord _weight(hc.WeightRecord record) => _record(
    record: record,
    type: 'body.weight',
    startTime: record.time,
    endTime: record.time,
    value: {'kilograms': record.weight.inKilograms},
  );

  HealthRecord _heartRate(hc.HeartRateSeriesRecord record) => _record(
    record: record,
    type: 'heart.rate',
    startTime: record.startTime,
    endTime: record.endTime,
    value: {
      'averageBpm': record.avgRate.inPerMinute,
      'minimumBpm': record.minRate.inPerMinute,
      'maximumBpm': record.maxRate.inPerMinute,
      'samples': record.samples
          .map(
            (sample) => {
              'time': sample.time.millisecondsSinceEpoch,
              'bpm': sample.rate.inPerMinute,
            },
          )
          .toList(),
    },
  );

  HealthRecord _restingHeartRate(hc.RestingHeartRateRecord record) => _record(
    record: record,
    type: 'heart.resting',
    startTime: record.time,
    endTime: record.time,
    value: {'bpm': record.rate.inPerMinute},
  );

  HealthRecord _instantHeartRate(hc.HeartRateRecord record) => _record(
    record: record,
    type: 'heart.rate',
    startTime: record.time,
    endTime: record.time,
    value: {
      'averageBpm': record.rate.inPerMinute,
      'minimumBpm': record.rate.inPerMinute,
      'maximumBpm': record.rate.inPerMinute,
      'samples': [
        {
          'time': record.time.millisecondsSinceEpoch,
          'bpm': record.rate.inPerMinute,
        },
      ],
    },
  );

  HealthRecord _sleep(hc.SleepSessionRecord record) => _record(
    record: record,
    type: 'sleep.session',
    startTime: record.startTime,
    endTime: record.endTime,
    value: {
      'title': record.title,
      'stages': record.samples
          .map(
            (stage) => {
              'startTime': stage.startTime.millisecondsSinceEpoch,
              'endTime': stage.endTime.millisecondsSinceEpoch,
              'type': stage.stageType.name,
            },
          )
          .toList(),
    },
  );

  HealthRecord _workout(
    hc.ExerciseSessionRecord record,
    List<hc.HeartRateSeriesRecord> heartRates,
    List<hc.DistanceRecord> distances,
    List<hc.ActiveEnergyBurnedRecord> activeEnergy,
    List<hc.SpeedSeriesRecord> speeds,
    Set<String> usedMetricIds,
  ) {
    final matchingHeartRates = heartRates.where(
      (item) => _matches(record, item) && usedMetricIds.add(item.id.value),
    );
    final matchingDistances = distances.where(
      (item) => _matches(record, item) && usedMetricIds.add(item.id.value),
    );
    final matchingEnergy = activeEnergy.where(
      (item) => _matches(record, item) && usedMetricIds.add(item.id.value),
    );
    final matchingSpeeds = speeds.where(
      (item) => _matches(record, item) && usedMetricIds.add(item.id.value),
    );
    final heartSamples = matchingHeartRates
        .expand((item) => item.samples)
        .map(
          (sample) => {
            'time': sample.time.millisecondsSinceEpoch,
            'value': sample.rate.inPerMinute,
          },
        )
        .toList();
    final speedSamples = matchingSpeeds
        .expand((item) => item.samples)
        .map(
          (sample) => {
            'time': sample.time.millisecondsSinceEpoch,
            'value': sample.speed.inKilometersPerHour,
          },
        )
        .toList();
    final laps = record.lapEvents
        .map(
          (lap) => {
            'startTime': lap.startTime.millisecondsSinceEpoch,
            'endTime': lap.endTime.millisecondsSinceEpoch,
            'distanceKm': lap.distance?.inKilometers,
          },
        )
        .toList();
    return _record(
      record: record,
      type: 'workout.healthConnect',
      startTime: record.startTime,
      endTime: record.endTime,
      value: {
        'exerciseType': record.exerciseType.name,
        'title': record.title,
        'notes': record.notes,
        'distanceKm': matchingDistances.fold<double>(
          0,
          (sum, item) => sum + item.distance.inKilometers,
        ),
        'calories': matchingEnergy.fold<double>(
          0,
          (sum, item) => sum + item.energy.inKilocalories,
        ),
        'averageHeartRate': heartSamples.isEmpty
            ? null
            : heartSamples
                      .map((sample) => sample['value'] as num)
                      .reduce((a, b) => a + b) /
                  heartSamples.length,
        'maximumHeartRate': heartSamples.isEmpty
            ? null
            : heartSamples
                  .map((sample) => sample['value'] as num)
                  .reduce((a, b) => a > b ? a : b),
        'averageSpeedKmh': speedSamples.isEmpty
            ? null
            : speedSamples
                      .map((sample) => sample['value'] as num)
                      .reduce((a, b) => a + b) /
                  speedSamples.length,
        'maximumSpeedKmh': speedSamples.isEmpty
            ? null
            : speedSamples
                  .map((sample) => sample['value'] as num)
                  .reduce((a, b) => a > b ? a : b),
        'heartRateSamples': heartSamples,
        'speedSamples': speedSamples,
        'laps': laps,
      },
    );
  }

  bool _matches(
    hc.IntervalHealthRecord session,
    hc.IntervalHealthRecord record,
  ) {
    final overlap =
        (record.endTime.isBefore(session.endTime)
                ? record.endTime
                : session.endTime)
            .difference(
              record.startTime.isAfter(session.startTime)
                  ? record.startTime
                  : session.startTime,
            );
    final shorter = record.endTime.difference(record.startTime);
    return !overlap.isNegative &&
        shorter.inMilliseconds > 0 &&
        overlap.inMilliseconds / shorter.inMilliseconds >= 0.8;
  }

  HealthRecord _record({
    required hc.HealthRecord record,
    required String type,
    required DateTime startTime,
    required DateTime endTime,
    required Map<String, dynamic> value,
  }) {
    final id = record.id.value;
    final sourceName = record.metadata.dataOrigin?.packageName;
    final updatedAt =
        record.metadata.lastModifiedTime?.millisecondsSinceEpoch ??
        endTime.millisecondsSinceEpoch;
    return HealthRecord(
      id: 'health-connect-$id',
      source: source,
      sourceRecordId: id,
      type: type,
      startTime: startTime.millisecondsSinceEpoch,
      endTime: endTime.millisecondsSinceEpoch,
      value: {
        ...value,
        if (record.metadata.clientRecordId != null)
          'clientRecordId': record.metadata.clientRecordId,
      },
      sourceName: sourceName,
      aggregateIncluded: true,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      deleted: false,
      synced: false,
    );
  }
}
