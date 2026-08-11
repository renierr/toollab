import 'dart:io';
import 'dart:math';

import 'package:health_connector/health_connector.dart' as hc;
// ignore: implementation_imports
import 'package:health_connector_core/src/models/health_data_types/health_data_type_capabilities/writeable_health_data_type.dart'
    as core;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/background_work_lease.dart';

import '../collectors/health_connect_types.dart';
import '../health_debug_origin.dart';
import 'health_debug_data.dart';

enum HealthDebugOutcome {
  ran,
  unsupported,
  noPermission,
  nothingSelected,

  /// Health Connect refused the run itself - a permission missing from the
  /// manifest is the usual cause, and it is a build problem, not a user choice.
  failed,
}

class HealthDebugResult {
  final HealthDebugOutcome outcome;
  final int records;
  final int failed;

  const HealthDebugResult(this.outcome, {this.records = 0, this.failed = 0});
}

/// Writes a synthetic health history into Health Connect so the dashboard has
/// something to render on a device that holds no real data.
///
/// Debug builds only - the entry point that reaches this is behind `kDebugMode`.
///
/// Every record carries a client record id of
/// `${healthDebugClientIdPrefix}<epoch day>:<part>`. Two things follow. The
/// prefix is what makes the data removable again - a wipe reads records back and
/// deletes the ones carrying it, so nothing this app wrote for real, treadmill
/// workouts above all, is touched; it is also what files the rows under
/// [healthDebugPackage] on the way in. And because the id is derived from the
/// day rather than from the run, generating the same day twice replaces its
/// records instead of adding a second copy.
class HealthDebugSeeder {
  const HealthDebugSeeder();

  /// Health Connect rejects an oversized insert, and a failed batch loses the
  /// good records in it too, so days are written in small groups.
  static const _batchSize = 200;
  static const _deleteChunk = 100;

  /// Sampled every 20 minutes: dense enough for a readable day chart, still one
  /// record per day.
  static const _heartSampleMinutes = 20;

  /// Waking hours 7:00-21:00, as a share of the day's step count.
  static const _stepShape = [
    0.03,
    0.06,
    0.09,
    0.07,
    0.05,
    0.08,
    0.10,
    0.07,
    0.05,
    0.06,
    0.08,
    0.09,
    0.07,
    0.06,
    0.04,
  ];
  static const _stepShapeFirstHour = 7;

  /// Everything the generator can write. Drives both the permission request and
  /// the read-back a wipe needs; `BodyMassIndexRecord` is deliberately absent
  /// because Health Connect has no such record type.
  static final _typesByGroup = <HealthDebugGroup, List<hc.HealthDataType>>{
    HealthDebugGroup.activity: [
      hc.HealthDataType.steps,
      hc.HealthDataType.distance,
      hc.HealthDataType.activeEnergyBurned,
      hc.HealthDataType.totalEnergyBurned,
      hc.HealthDataType.floorsClimbed,
      hc.HealthDataType.elevationGained,
    ],
    HealthDebugGroup.heart: [
      hc.HealthDataType.heartRateSeries,
      hc.HealthDataType.restingHeartRate,
      hc.HealthDataType.heartRateVariabilityRMSSD,
    ],
    HealthDebugGroup.sleep: [hc.HealthDataType.sleepSession],
    HealthDebugGroup.workouts: [
      hc.HealthDataType.exerciseSession,
      hc.HealthDataType.speedSeries,
      hc.HealthDataType.distance,
      hc.HealthDataType.activeEnergyBurned,
      hc.HealthDataType.steps,
    ],
    HealthDebugGroup.body: [
      hc.HealthDataType.weight,
      hc.HealthDataType.bodyFatPercentage,
      hc.HealthDataType.leanBodyMass,
      hc.HealthDataType.boneMass,
      hc.HealthDataType.bodyWaterMass,
      hc.HealthDataType.height,
    ],
    HealthDebugGroup.vitals: [
      hc.HealthDataType.oxygenSaturation,
      hc.HealthDataType.respiratoryRate,
      hc.HealthDataType.bloodPressure,
      hc.HealthDataType.bodyTemperature,
      hc.HealthDataType.bloodGlucose,
    ],
    HealthDebugGroup.hydration: [hc.HealthDataType.hydration],
  };

  static final _allTypeIds = {
    for (final types in _typesByGroup.values)
      for (final type in types) HealthConnectTypes.idOf(type),
  };

  /// Writes [days] of generated data ending today, one day at a time.
  Future<HealthDebugResult> seed({
    required int days,
    required Set<HealthDebugGroup> groups,
    void Function(String status, int written)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      return const HealthDebugResult(HealthDebugOutcome.unsupported);
    }
    if (groups.isEmpty) {
      return const HealthDebugResult(HealthDebugOutcome.nothingSelected);
    }
    try {
      return await _seed(days: days, groups: groups, onProgress: onProgress);
    } catch (e) {
      errorLog('[HealthDebug] Generating data failed: $e');
      return const HealthDebugResult(HealthDebugOutcome.failed);
    }
  }

  Future<HealthDebugResult> _seed({
    required int days,
    required Set<HealthDebugGroup> groups,
    void Function(String status, int written)? onProgress,
  }) async {
    final connector = await hc.HealthConnector.create();
    final permissions = _writePermissions([
      for (final group in groups) ..._typesByGroup[group]!,
    ]);
    final access = await _ensureAccess(connector, permissions);
    if (access != HealthDebugOutcome.ran) {
      return HealthDebugResult(access);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final work = await BackgroundWorkLease.acquire(
      title: 'Health debug data',
      text: 'Generating $days day(s)...',
      logPrefix: 'HealthDebug',
    );
    var written = 0;
    var failed = 0;
    final batch = <hc.HealthRecord>[];

    Future<void> flush() async {
      if (batch.isEmpty) return;
      try {
        await connector.writeRecords(List<hc.HealthRecord>.of(batch));
        written += batch.length;
      } catch (e) {
        // A batch is rejected as a whole, so one record this Health Connect
        // version will not take would cost the other 199. Retrying one at a time
        // isolates it instead.
        errorLog('[HealthDebug] Batch of ${batch.length} rejected: $e');
        for (final record in batch) {
          try {
            await connector.writeRecords([record]);
            written++;
          } catch (e) {
            failed++;
            errorLog('[HealthDebug] ${record.runtimeType} rejected: $e');
          }
        }
      }
      batch.clear();
      onProgress?.call('Writing generated data...', written);
      await work.update('Wrote $written record(s)');
    }

    try {
      for (var back = days - 1; back >= 0; back--) {
        final day = today.subtract(Duration(days: back));
        // Today is only half over, so anything the shape puts later than now is
        // dropped rather than written into the future.
        batch.addAll(
          _recordsForDay(
            day,
            groups,
            now,
          ).where((r) => !_endOf(r).isAfter(now)),
        );
        if (batch.length >= _batchSize) await flush();
      }
      await flush();
    } finally {
      await work.release();
    }
    return HealthDebugResult(
      HealthDebugOutcome.ran,
      records: written,
      failed: failed,
    );
  }

  /// Deletes every record carrying [healthDebugClientIdPrefix].
  ///
  /// The window is wide on purpose: what was generated is not recorded anywhere,
  /// so the only way to find it again is to read the types the generator uses
  /// and keep the records whose client id it stamped.
  Future<HealthDebugResult> clear({
    void Function(String status, int removed)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      return const HealthDebugResult(HealthDebugOutcome.unsupported);
    }
    try {
      return await _clear(onProgress: onProgress);
    } catch (e) {
      errorLog('[HealthDebug] Removing generated data failed: $e');
      return const HealthDebugResult(HealthDebugOutcome.failed);
    }
  }

  Future<HealthDebugResult> _clear({
    void Function(String status, int removed)? onProgress,
  }) async {
    final connector = await hc.HealthConnector.create();
    final permissions = [
      ..._writePermissions([
        for (final types in _typesByGroup.values) ...types,
      ]),
      for (final readable in HealthConnectTypes.readable())
        if (_allTypeIds.contains(HealthConnectTypes.idOf(readable)))
          readable.readPermission,
    ];
    final access = await _ensureAccess(connector, permissions);
    if (access != HealthDebugOutcome.ran) {
      return HealthDebugResult(access);
    }

    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 800));
    final to = now.add(const Duration(days: 1));
    final work = await BackgroundWorkLease.acquire(
      title: 'Health debug data',
      text: 'Removing generated data...',
      logPrefix: 'HealthDebug',
    );
    var removed = 0;
    try {
      for (final readable in HealthConnectTypes.readable()) {
        final typeId = HealthConnectTypes.idOf(readable);
        if (!_allTypeIds.contains(typeId)) continue;
        try {
          final ids = <hc.HealthRecordId>[];
          dynamic request = readable.readInTimeRange(
            startTime: from,
            endTime: to,
            pageSize: 1000,
          );
          do {
            final dynamic response = await connector.readRecords(request);
            for (final record
                in (response.records as List).cast<hc.HealthRecord>()) {
              final clientId = record.metadata.clientRecordId;
              if (clientId == null ||
                  !clientId.startsWith(healthDebugClientIdPrefix)) {
                continue;
              }
              if (record.id == hc.HealthRecordId.none) continue;
              ids.add(record.id);
            }
            request = response.nextPageRequest;
          } while (request != null);

          for (var i = 0; i < ids.length; i += _deleteChunk) {
            final chunk = ids.sublist(i, min(i + _deleteChunk, ids.length));
            // The request type is not exported by the plugin, so it stays
            // inferred - the same shape the importer uses for reads.
            await connector.deleteRecords(
              (readable as dynamic).deleteByIds(chunk),
            );
            removed += chunk.length;
            onProgress?.call('Removing generated data...', removed);
            await work.update('Removed $removed record(s)');
          }
        } catch (e) {
          // A type this Health Connect build cannot read or delete must not
          // abort the rest of the wipe.
          errorLog('[HealthDebug] Clearing $typeId failed: $e');
        }
      }
    } finally {
      await work.release();
    }
    return HealthDebugResult(HealthDebugOutcome.ran, records: removed);
  }

  /// The write capability is not part of the exported `HealthDataType` surface,
  /// so it takes a cast - safe because every type in [_typesByGroup] is one the
  /// generator writes.
  static List<hc.HealthDataPermission> _writePermissions(
    Iterable<hc.HealthDataType> types,
  ) => [
    for (final type in types)
      (type as core.WriteableHealthDataType).writePermission,
  ];

  /// [HealthDebugOutcome.ran] means the run may proceed.
  ///
  /// A write permission that is not declared in the manifest makes
  /// `requestPermissions` throw rather than come back denied - a build problem
  /// the debug source set has to fix, which is why it is reported apart from a
  /// declined request instead of crashing the isolate.
  Future<HealthDebugOutcome> _ensureAccess(
    hc.HealthConnector connector,
    List<hc.HealthDataPermission> needed,
  ) async {
    if (needed.isEmpty) return HealthDebugOutcome.nothingSelected;
    try {
      final results = await connector.requestPermissions(needed);
      if (results.any(
        (result) => result.status == hc.PermissionStatus.granted,
      )) {
        return HealthDebugOutcome.ran;
      }
    } catch (e) {
      errorLog('[HealthDebug] Requesting permissions failed: $e');
      return HealthDebugOutcome.failed;
    }
    // Already-granted permissions are not requestable, so the request comes
    // back empty-handed and the granted set has to decide.
    try {
      final granted = await connector.getGrantedPermissions();
      return needed.any(granted.contains)
          ? HealthDebugOutcome.ran
          : HealthDebugOutcome.noPermission;
    } catch (e) {
      errorLog('[HealthDebug] Reading granted permissions failed: $e');
      return HealthDebugOutcome.failed;
    }
  }

  static DateTime _endOf(hc.HealthRecord record) => switch (record) {
    hc.InstantHealthRecord(:final time) => time,
    hc.IntervalHealthRecord(:final endTime) => endTime,
  };

  List<hc.HealthRecord> _recordsForDay(
    DateTime day,
    Set<HealthDebugGroup> groups,
    DateTime now,
  ) {
    final epochDay = day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    // Seeded per day rather than per run, so a 7 day set and a 3 month set agree
    // on the days they share and a regenerate reproduces the same shape.
    final rng = Random(epochDay);
    return [
      if (groups.contains(HealthDebugGroup.activity))
        ..._activity(day, epochDay, rng),
      if (groups.contains(HealthDebugGroup.heart))
        ..._heart(day, epochDay, rng, now),
      if (groups.contains(HealthDebugGroup.sleep))
        ..._sleep(day, epochDay, rng),
      if (groups.contains(HealthDebugGroup.workouts))
        ..._workout(day, epochDay, rng),
      if (groups.contains(HealthDebugGroup.body)) ..._body(day, epochDay, rng),
      if (groups.contains(HealthDebugGroup.vitals))
        ..._vitals(day, epochDay, rng),
      if (groups.contains(HealthDebugGroup.hydration))
        ..._hydration(day, epochDay, rng),
    ];
  }

  List<hc.HealthRecord> _activity(DateTime day, int epochDay, Random rng) {
    final total = 6000 + rng.nextInt(7000);
    final records = <hc.HealthRecord>[];
    var walked = 0;
    for (var i = 0; i < _stepShape.length; i++) {
      final hour = _stepShapeFirstHour + i;
      final count = (total * _stepShape[i] * (0.8 + rng.nextDouble() * 0.4))
          .round();
      if (count <= 0) continue;
      walked += count;
      records.add(
        hc.StepsRecord(
          startTime: _at(day, hour),
          endTime: _at(day, hour, 59),
          count: hc.Number(count),
          metadata: _meta(epochDay, 'steps-$hour'),
        ),
      );
    }
    // Distance and energy in thirds of the day: enough shape for the intraday
    // chart without one record per hour.
    const blocks = [(7, 12), (12, 17), (17, 22)];
    for (var i = 0; i < blocks.length; i++) {
      final (from, to) = blocks[i];
      final share = walked / blocks.length;
      records.add(
        hc.DistanceRecord(
          startTime: _at(day, from),
          endTime: _at(day, to),
          distance: hc.Length.kilometers(share * 0.00072),
          metadata: _meta(epochDay, 'distance-$i'),
        ),
      );
      records.add(
        hc.ActiveEnergyBurnedRecord(
          startTime: _at(day, from),
          endTime: _at(day, to),
          energy: hc.Energy.kilocalories(share * 0.04),
          metadata: _meta(epochDay, 'active-energy-$i'),
        ),
      );
    }
    final floors = 3 + rng.nextInt(12);
    records.add(
      hc.FloorsClimbedRecord(
        startTime: _at(day, 7),
        endTime: _at(day, 22),
        count: hc.Number(floors),
        metadata: _meta(epochDay, 'floors'),
      ),
    );
    records.add(
      hc.ElevationGainedRecord(
        startTime: _at(day, 7),
        endTime: _at(day, 22),
        elevation: hc.Length.meters(floors * 3.0),
        metadata: _meta(epochDay, 'elevation'),
      ),
    );
    records.add(
      hc.TotalEnergyBurnedRecord(
        startTime: _at(day, 0),
        endTime: _at(day, 23, 59),
        energy: hc.Energy.kilocalories(1750 + walked * 0.04),
        metadata: _meta(epochDay, 'total-energy'),
      ),
    );
    return records;
  }

  List<hc.HealthRecord> _heart(
    DateTime day,
    int epochDay,
    Random rng,
    DateTime now,
  ) {
    final resting = 52 + rng.nextInt(9);
    final samples = <hc.HeartRateSample>[];
    var last = _at(day, 0);
    for (
      var minute = 0;
      minute < Duration.minutesPerDay;
      minute += _heartSampleMinutes
    ) {
      final time = _at(day, 0).add(Duration(minutes: minute));
      if (time.isAfter(now)) break;
      final hour = minute ~/ 60;
      final asleep = hour < 6 || hour >= 23;
      final rate = asleep
          ? resting + rng.nextInt(6)
          : 62 + rng.nextInt(28) + (hour >= 17 && hour < 20 ? 20 : 0);
      samples.add(
        hc.HeartRateSample(
          time: time,
          rate: hc.Frequency.perMinute(rate.toDouble()),
        ),
      );
      last = time;
    }
    return [
      if (samples.isNotEmpty)
        hc.HeartRateSeriesRecord(
          startTime: _at(day, 0),
          endTime: last.add(const Duration(minutes: 1)),
          samples: samples,
          metadata: _meta(epochDay, 'heart-rate'),
        ),
      hc.RestingHeartRateRecord(
        time: _at(day, 7),
        rate: hc.Frequency.perMinute(resting.toDouble()),
        metadata: _meta(epochDay, 'resting-heart-rate'),
      ),
      hc.HeartRateVariabilityRMSSDRecord(
        time: _at(day, 7, 5),
        rmssd: hc.TimeDuration.milliseconds(45 + rng.nextInt(35).toDouble()),
        metadata: _meta(epochDay, 'hrv'),
      ),
    ];
  }

  /// The night that starts on [day]: bed late in the evening, up the next
  /// morning, in roughly 90 minute cycles.
  List<hc.HealthRecord> _sleep(DateTime day, int epochDay, Random rng) {
    final start = _at(day, 22, 45).add(Duration(minutes: rng.nextInt(60)));
    final end = start.add(Duration(minutes: 375 + rng.nextInt(120)));
    final stages = <hc.SleepStageSample>[];
    var cursor = start;
    var cycle = 0;
    while (cursor.isBefore(end)) {
      final plan = <(hc.SleepStage, int)>[
        (hc.SleepStage.light, 40),
        (hc.SleepStage.deep, cycle < 2 ? 35 : 20),
        (hc.SleepStage.rem, 15 + cycle * 5),
        if (cycle > 0) (hc.SleepStage.awake, 5),
      ];
      for (final (stage, minutes) in plan) {
        if (!cursor.isBefore(end)) break;
        var stageEnd = cursor.add(Duration(minutes: minutes));
        if (stageEnd.isAfter(end)) stageEnd = end;
        if (!stageEnd.isAfter(cursor)) break;
        stages.add(
          hc.SleepStageSample(
            startTime: cursor,
            endTime: stageEnd,
            stageType: stage,
          ),
        );
        cursor = stageEnd;
      }
      cycle++;
    }
    return [
      hc.SleepSessionRecord(
        id: hc.HealthRecordId.none,
        startTime: start,
        endTime: end,
        samples: stages,
        title: 'Sleep',
        metadata: _meta(epochDay, 'sleep'),
      ),
    ];
  }

  /// Three sessions a week, picked by the day itself so the pattern is stable.
  List<hc.HealthRecord> _workout(DateTime day, int epochDay, Random rng) {
    final slot = epochDay % 7;
    final (type, minutes, speedKmh) = switch (slot) {
      1 => (hc.ExerciseType.running, 40, 10.5),
      3 => (hc.ExerciseType.cycling, 55, 25.0),
      5 => (hc.ExerciseType.strengthTraining, 45, 0.0),
      _ => (hc.ExerciseType.other, 0, 0.0),
    };
    if (minutes == 0) return const [];
    final start = _at(day, 18).add(Duration(minutes: rng.nextInt(45)));
    final end = start.add(Duration(minutes: minutes));
    final records = <hc.HealthRecord>[
      hc.ExerciseSessionRecord(
        startTime: start,
        endTime: end,
        exerciseType: type,
        title: type.name,
        metadata: _meta(epochDay, 'exercise'),
      ),
      hc.ActiveEnergyBurnedRecord(
        startTime: start,
        endTime: end,
        energy: hc.Energy.kilocalories(minutes * 9.5),
        metadata: _meta(epochDay, 'workout-energy'),
      ),
    ];
    if (speedKmh > 0) {
      final samples = <hc.SpeedSample>[];
      for (var minute = 0; minute < minutes; minute++) {
        samples.add(
          hc.SpeedSample(
            time: start.add(Duration(minutes: minute)),
            speed: hc.Velocity.kilometersPerHour(
              speedKmh + rng.nextDouble() * 3 - 1.5,
            ),
          ),
        );
      }
      records.add(
        hc.SpeedSeriesRecord(
          startTime: start,
          endTime: end,
          samples: samples,
          metadata: _meta(epochDay, 'workout-speed'),
        ),
      );
      records.add(
        hc.DistanceRecord(
          startTime: start,
          endTime: end,
          distance: hc.Length.kilometers(speedKmh * minutes / 60),
          metadata: _meta(epochDay, 'workout-distance'),
        ),
      );
    }
    if (type == hc.ExerciseType.running) {
      records.add(
        hc.StepsRecord(
          startTime: start,
          endTime: end,
          count: hc.Number(minutes * 165),
          metadata: _meta(epochDay, 'workout-steps'),
        ),
      );
    }
    return records;
  }

  /// A slow trend rather than noise, so the weight chart has a direction.
  List<hc.HealthRecord> _body(DateTime day, int epochDay, Random rng) {
    if (epochDay.isOdd) return const [];
    final weight = 78 + sin(epochDay / 30) * 1.5 + rng.nextDouble() * 0.6 - 0.3;
    final fat = 18 + sin(epochDay / 45) * 1.5;
    final records = <hc.HealthRecord>[
      hc.WeightRecord(
        time: _at(day, 7, 20),
        weight: hc.Mass.kilograms(weight),
        metadata: _meta(epochDay, 'weight'),
      ),
      hc.BodyFatPercentageRecord(
        time: _at(day, 7, 21),
        percentage: hc.Percentage.fromWhole(fat),
        metadata: _meta(epochDay, 'body-fat'),
      ),
      hc.LeanBodyMassRecord(
        time: _at(day, 7, 22),
        mass: hc.Mass.kilograms(weight * (1 - fat / 100)),
        metadata: _meta(epochDay, 'lean-mass'),
      ),
    ];
    if (epochDay % 7 == 0) {
      records.add(
        hc.BoneMassRecord(
          time: _at(day, 7, 23),
          mass: hc.Mass.kilograms(3.1 + rng.nextDouble() * 0.2),
          metadata: _meta(epochDay, 'bone-mass'),
        ),
      );
      records.add(
        hc.BodyWaterMassRecord(
          time: _at(day, 7, 24),
          mass: hc.Mass.kilograms(weight * 0.57),
          metadata: _meta(epochDay, 'body-water'),
        ),
      );
      records.add(
        hc.HeightRecord(
          time: _at(day, 7, 25),
          height: hc.Length.centimeters(182),
          metadata: _meta(epochDay, 'height'),
        ),
      );
    }
    return records;
  }

  List<hc.HealthRecord> _vitals(DateTime day, int epochDay, Random rng) {
    final records = <hc.HealthRecord>[
      hc.OxygenSaturationRecord(
        time: _at(day, 7, 10),
        saturation: hc.Percentage.fromWhole(96 + rng.nextInt(3).toDouble()),
        metadata: _meta(epochDay, 'oxygen'),
      ),
      hc.RespiratoryRateRecord(
        time: _at(day, 7, 12),
        rate: hc.Frequency.perMinute(13 + rng.nextInt(4).toDouble()),
        metadata: _meta(epochDay, 'respiratory-rate'),
      ),
      hc.BloodPressureRecord(
        time: _at(day, 7, 15),
        systolic: hc.Pressure.millimetersOfMercury(
          115 + rng.nextInt(15).toDouble(),
        ),
        diastolic: hc.Pressure.millimetersOfMercury(
          72 + rng.nextInt(10).toDouble(),
        ),
        metadata: _meta(epochDay, 'blood-pressure'),
      ),
    ];
    if (epochDay % 7 == 0) {
      records.add(
        hc.BodyTemperatureRecord(
          time: _at(day, 7, 30),
          temperature: hc.Temperature.celsius(36.4 + rng.nextDouble() * 0.6),
          metadata: _meta(epochDay, 'temperature'),
        ),
      );
    }
    if (epochDay % 3 == 0) {
      const hours = [8, 13, 19];
      for (var i = 0; i < hours.length; i++) {
        records.add(
          hc.BloodGlucoseRecord(
            time: _at(day, hours[i], 30),
            glucoseLevel: hc.BloodGlucose.millimolesPerLiter(
              4.6 + rng.nextDouble() * 2.6,
            ),
            metadata: _meta(epochDay, 'glucose-$i'),
          ),
        );
      }
    }
    return records;
  }

  List<hc.HealthRecord> _hydration(DateTime day, int epochDay, Random rng) {
    const hours = [8, 11, 14, 17];
    return [
      for (var i = 0; i < hours.length; i++)
        hc.HydrationRecord(
          startTime: _at(day, hours[i]),
          endTime: _at(day, hours[i], 5),
          volume: hc.Volume.liters(0.25 + rng.nextDouble() * 0.25),
          metadata: _meta(epochDay, 'hydration-$i'),
        ),
    ];
  }

  static DateTime _at(DateTime day, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  hc.Metadata _meta(int epochDay, String part) =>
      hc.Metadata.automaticallyRecorded(
        device: const hc.Device(
          type: hc.DeviceType.phone,
          name: 'Debug generator',
        ),
        clientRecordId: '$healthDebugClientIdPrefix$epochDay:$part',
        clientRecordVersion: 1,
      );
}
