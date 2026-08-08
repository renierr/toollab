import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;

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
      hc.HealthDataType.steps.readPermission,
      hc.HealthDataType.weight.readPermission,
      hc.HealthDataType.heartRateSeries.readPermission,
      hc.HealthDataType.restingHeartRate.readPermission,
      hc.HealthDataType.sleepSession.readPermission,
      hc.HealthDataType.exerciseSession.readPermission,
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
    records.addAll(workouts.records.map(_workout));
    return records;
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

  HealthRecord _workout(hc.ExerciseSessionRecord record) => _record(
    record: record,
    type: 'workout.healthConnect',
    startTime: record.startTime,
    endTime: record.endTime,
    value: {'exerciseType': record.exerciseType.name, 'title': record.title},
  );

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
      value: value,
      sourceName: sourceName,
      aggregateIncluded: true,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      deleted: false,
      synced: false,
    );
  }
}
