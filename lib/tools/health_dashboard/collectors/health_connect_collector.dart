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
  static final _initialImportStart = DateTime.utc(1970);

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
    final importStart = start ?? _initialImportStart;
    final records = <HealthRecord>[];

    // Persist every readable record so data that has no dedicated dashboard yet
    // remains available in All Health Data. Rich converters below replace these.
    records.addAll(await _allRecords(connector, importStart, end));

    final steps = await connector.readRecords(
      hc.HealthDataType.steps.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    records.addAll(steps.records.map(_steps));

    final weights = await connector.readRecords(
      hc.HealthDataType.weight.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    records.addAll(weights.records.map(_weight));

    final heartRates = await connector.readRecords(
      hc.HealthDataType.heartRateSeries.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    records.addAll(heartRates.records.map(_heartRate));

    final restingRates = await connector.readRecords(
      hc.HealthDataType.restingHeartRate.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    records.addAll(restingRates.records.map(_restingHeartRate));

    final sleep = await connector.readRecords(
      hc.HealthDataType.sleepSession.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    records.addAll(sleep.records.map(_sleep));

    final workouts = await connector.readRecords(
      hc.HealthDataType.exerciseSession.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    final distances = await connector.readRecords(
      hc.HealthDataType.distance.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    final activeEnergy = await connector.readRecords(
      hc.HealthDataType.activeEnergyBurned.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    final speeds = await connector.readRecords(
      hc.HealthDataType.speedSeries.readInTimeRange(
        startTime: importStart,
        endTime: end,
      ),
    );
    records.addAll(
      workouts.records.map(
        (workout) => _workout(
          workout,
          heartRates.records,
          distances.records,
          activeEnergy.records,
          speeds.records,
        ),
      ),
    );
    return records;
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
      },
    );
  }

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
  ) {
    final matchingHeartRates = heartRates.where(
      (item) => _matches(record, item),
    );
    final matchingDistances = distances.where((item) => _matches(record, item));
    final matchingEnergy = activeEnergy.where((item) => _matches(record, item));
    final matchingSpeeds = speeds.where((item) => _matches(record, item));
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
  ) =>
      record.startTime.compareTo(session.startTime) >= 0 &&
      record.endTime.compareTo(session.endTime) <= 0 &&
      record.metadata.dataOrigin?.packageName ==
          session.metadata.dataOrigin?.packageName;

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
