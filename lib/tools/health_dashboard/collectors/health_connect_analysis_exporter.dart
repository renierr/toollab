import 'dart:convert';
import 'dart:io';

import 'package:health_connector/health_connector.dart' as hc;
// ignore: implementation_imports
import 'package:health_connector_core/src/models/health_data_types/health_data_type_capabilities/readable_health_data_type.dart'
    as core;
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

class HealthConnectAnalysisExporter {
  static const _readPageSize = 5000;
  static const _writeBatchSize = 2000;
  static const _comparisonSources = {
    'com.huami.watch.hmwatchmanager',
    'com.google.android.apps.fitness',
    'com.renpho.health',
  };

  Future<String> exportComparison({
    required void Function(String status, int count) onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Health Connect is only available on Android.');
    }
    final connector = await hc.HealthConnector.create();
    final path = await FileSaveHelper.createAndroidDownloadsFilePath(
      'health_connect_comparison.db',
    );
    final database = await openDatabase(path);
    var total = 0;
    try {
      await database.execute('''
        CREATE TABLE comparison_metrics (
          source_name TEXT NOT NULL,
          source_record_id TEXT NOT NULL,
          health_type TEXT NOT NULL,
          metric_type TEXT NOT NULL,
          time INTEGER NOT NULL,
          end_time INTEGER,
          value REAL NOT NULL,
          value_secondary REAL,
          unit TEXT NOT NULL,
          PRIMARY KEY (source_name, source_record_id, metric_type, time, value, value_secondary)
        )
      ''');
      await database.execute(
        'CREATE INDEX comparison_metrics_lookup '
        'ON comparison_metrics (metric_type, time, source_name)',
      );
      final List<dynamic> types = [
        hc.HealthDataType.steps,
        hc.HealthDataType.weight,
        hc.HealthDataType.bodyFatPercentage,
        hc.HealthDataType.distance,
        hc.HealthDataType.activeEnergyBurned,
        hc.HealthDataType.heartRate,
        hc.HealthDataType.heartRateSeries,
        hc.HealthDataType.restingHeartRate,
        hc.HealthDataType.speedSeries,
        hc.HealthDataType.oxygenSaturation,
        hc.HealthDataType.respiratoryRate,
        hc.HealthDataType.bloodPressure,
        hc.HealthDataType.sleepSession,
        hc.HealthDataType.exerciseSession,
      ];
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 90));
      for (final type in types) {
        onProgress('Comparing ${type.id}...', total);
        try {
          dynamic request = type.readInTimeRange(
            startTime: start,
            endTime: end,
            pageSize: _readPageSize,
          );
          do {
            final dynamic response = await connector.readRecords(request);
            final records = (response.records as List).cast<hc.HealthRecord>();
            final batch = database.batch();
            for (final record in records) {
              final sourceName = record.metadata.dataOrigin?.packageName;
              if (!_comparisonSources.contains(sourceName)) continue;
              final (recordStart, recordEnd) = switch (record) {
                hc.InstantHealthRecord(:final time) => (time, time),
                hc.IntervalHealthRecord(:final startTime, :final endTime) => (
                  startTime,
                  endTime,
                ),
              };
              for (final metric in _structuredMetrics(
                record,
                recordStart,
                recordEnd,
              )) {
                batch.insert(
                  'comparison_metrics',
                  {
                    'source_name': sourceName,
                    'source_record_id': record.id.value,
                    'health_type': type.id,
                    ...metric,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }
            }
            await batch.commit(noResult: true);
            total += records.length;
            onProgress('Comparing ${type.id}...', total);
            request = response.nextPageRequest;
          } while (request != null);
        } catch (_) {
          // A type may be unavailable despite being exposed by the package.
        }
      }
      return path;
    } finally {
      await database.close();
    }
  }

  Future<String> export({
    required void Function(String status, int count) onProgress,
    bool fullHistory = true,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Health Connect is only available on Android.');
    }
    final platformStatus = await hc.HealthConnector.getHealthPlatformStatus();
    if (platformStatus != hc.HealthPlatformStatus.available) {
      throw StateError('Health Connect is unavailable: $platformStatus');
    }

    final connector = await hc.HealthConnector.create();
    final fileName = fullHistory
        ? 'health_connect_analysis.db'
        : 'health_connect_discovery.db';
    final path = Platform.isAndroid
        ? await FileSaveHelper.createAndroidDownloadsFilePath(fileName)
        : await TempFileManager.createFile(fileName);
    final database = await openDatabase(path);
    var totalRecords = 0;
    try {
      await _createSchema(database);
      await _insertRun(database, platformStatus, fullHistory: fullHistory);
      final end = DateTime.now();
      final start = DateTime.utc(1970);
      for (final type in hc.HealthDataType.healthConnectDataTypes) {
        final typeId = type.id;
        if (type is! core.ReadableInTimeRangeHealthDataType) {
          await _insertTypeStatus(
            database,
            typeId: typeId,
            status: 'skipped',
            detail: 'No time-range read API.',
          );
          continue;
        }
        onProgress('Analyzing $typeId...', totalRecords);
        try {
          final readable = type as core.ReadableInTimeRangeHealthDataType;
          dynamic request = readable.readInTimeRange(
            startTime: start,
            endTime: end,
            pageSize: _readPageSize,
          );
          var pages = 0;
          var typeRecords = 0;
          do {
            final dynamic response = await connector.readRecords(request);
            final page = (response.records as List).cast<hc.HealthRecord>();
            await _insertRecords(database, typeId, page);
            totalRecords += page.length;
            typeRecords += page.length;
            pages++;
            onProgress('Analyzing $typeId (page $pages)...', totalRecords);
            request = response.nextPageRequest;
          } while (fullHistory && request != null);
          await _insertTypeStatus(
            database,
            typeId: typeId,
            status: 'success',
            recordCount: typeRecords,
            pageCount: pages,
          );
        } catch (error) {
          await _insertTypeStatus(
            database,
            typeId: typeId,
            status: 'error',
            detail: error.toString(),
          );
        }
      }
      if (fullHistory) {
        onProgress('Analyzing exercise sessions...', totalRecords);
        try {
          await _createSessionAnalysis(database, connector);
        } catch (error) {
          await database.insert('analysis_run', {
            'key': 'exercise_session_analysis_error',
            'value': error.toString(),
          });
        }
      }
      await _createSummaryViews(database);
      return path;
    } finally {
      await database.close();
    }
  }

  Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE analysis_run (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE type_status (
        type_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        record_count INTEGER NOT NULL DEFAULT 0,
        page_count INTEGER NOT NULL DEFAULT 0,
        detail TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE raw_records (
        id TEXT PRIMARY KEY,
        type_id TEXT NOT NULL,
        record_class TEXT NOT NULL,
        source_record_id TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        source_name TEXT,
        last_modified_time INTEGER,
        client_record_id TEXT,
        client_record_version INTEGER,
        recording_method TEXT,
        device_json TEXT,
        raw_text TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE exercise_sessions (
        raw_record_id TEXT PRIMARY KEY,
        exercise_type TEXT NOT NULL,
        title TEXT,
        notes TEXT,
        events_json TEXT NOT NULL,
        route_json TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE structured_metrics (
        raw_record_id TEXT NOT NULL REFERENCES raw_records(id),
        metric_type TEXT NOT NULL,
        time INTEGER NOT NULL,
        end_time INTEGER,
        value REAL NOT NULL,
        value_secondary REAL,
        unit TEXT NOT NULL,
        PRIMARY KEY (raw_record_id, metric_type, time, value, value_secondary)
      )
    ''');
    await database.execute(
      'CREATE INDEX raw_records_type_time ON raw_records (type_id, start_time, end_time)',
    );
    await database.execute(
      'CREATE INDEX raw_records_source ON raw_records (source_name)',
    );
    await database.execute(
      'CREATE INDEX structured_metrics_type_time '
      'ON structured_metrics (metric_type, time)',
    );
  }

  Future<void> _insertRun(
    Database database,
    hc.HealthPlatformStatus platformStatus, {
    required bool fullHistory,
  }) async {
    final batch = database.batch();
    batch.insert('analysis_run', {
      'key': 'exported_at',
      'value': DateTime.now().toIso8601String(),
    });
    batch.insert('analysis_run', {
      'key': 'platform_status',
      'value': platformStatus.name,
    });
    batch.insert('analysis_run', {
      'key': 'package',
      'value': 'health_connector 3.9.x',
    });
    batch.insert('analysis_run', {
      'key': 'scope',
      'value': fullHistory ? 'full_history' : 'one_page_per_type',
    });
    await batch.commit(noResult: true);
  }

  Future<void> _insertTypeStatus(
    Database database, {
    required String typeId,
    required String status,
    int recordCount = 0,
    int pageCount = 0,
    String? detail,
  }) => database.insert('type_status', {
    'type_id': typeId,
    'status': status,
    'record_count': recordCount,
    'page_count': pageCount,
    'detail': detail,
  });

  Future<void> _insertRecords(
    Database database,
    String typeId,
    List<hc.HealthRecord> records,
  ) async {
    for (var offset = 0; offset < records.length; offset += _writeBatchSize) {
      final batch = database.batch();
      final batchEnd = offset + _writeBatchSize > records.length
          ? records.length
          : offset + _writeBatchSize;
      for (final record in records.sublist(offset, batchEnd)) {
        final (start, end) = switch (record) {
          hc.InstantHealthRecord(:final time) => (time, time),
          hc.IntervalHealthRecord(:final startTime, :final endTime) => (
            startTime,
            endTime,
          ),
        };
        final metadata = record.metadata;
        batch.insert('raw_records', {
          'id': '$typeId:${record.id.value}',
          'type_id': typeId,
          'record_class': record.runtimeType.toString(),
          'source_record_id': record.id.value,
          'start_time': start.millisecondsSinceEpoch,
          'end_time': end.millisecondsSinceEpoch,
          'source_name': metadata.dataOrigin?.packageName,
          'last_modified_time':
              metadata.lastModifiedTime?.millisecondsSinceEpoch,
          'client_record_id': metadata.clientRecordId,
          'client_record_version': metadata.clientRecordVersion,
          'recording_method': metadata.recordingMethod.name,
          'device_json': _deviceJson(metadata.device),
          'raw_text': record.toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        for (final metric in _structuredMetrics(record, start, end)) {
          batch.insert('structured_metrics', {
            'raw_record_id': '$typeId:${record.id.value}',
            ...metric,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    }
  }

  Iterable<Map<String, Object?>> _structuredMetrics(
    hc.HealthRecord record,
    DateTime start,
    DateTime end,
  ) sync* {
    Map<String, Object?> metric(
      String type,
      DateTime time,
      num value,
      String unit, {
      DateTime? endTime,
      num? secondary,
    }) => {
      'metric_type': type,
      'time': time.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'value': value.toDouble(),
      'value_secondary': secondary?.toDouble(),
      'unit': unit,
    };
    switch (record) {
      case hc.StepsRecord(:final count):
        yield metric('steps', start, count.value, 'count', endTime: end);
      case hc.WeightRecord(:final weight):
        yield metric('weight', start, weight.inKilograms, 'kg');
      case hc.BodyFatPercentageRecord(:final percentage):
        yield metric('body_fat', start, percentage.asWhole, 'percent');
      case hc.BodyWaterMassRecord(:final mass):
        yield metric('body_water', start, mass.inKilograms, 'kg');
      case hc.BoneMassRecord(:final mass):
        yield metric('bone_mass', start, mass.inKilograms, 'kg');
      case hc.LeanBodyMassRecord(:final mass):
        yield metric('lean_body_mass', start, mass.inKilograms, 'kg');
      case hc.DistanceRecord(:final distance):
        yield metric(
          'distance',
          start,
          distance.inKilometers,
          'km',
          endTime: end,
        );
      case hc.ActiveEnergyBurnedRecord(:final energy):
        yield metric(
          'active_calories',
          start,
          energy.inKilocalories,
          'kcal',
          endTime: end,
        );
      case hc.RestingHeartRateRecord(:final rate):
        yield metric('resting_heart_rate', start, rate.inPerMinute, 'bpm');
      case hc.HeartRateRecord(:final rate):
        yield metric('heart_rate', start, rate.inPerMinute, 'bpm');
      case hc.HeartRateSeriesRecord(:final samples):
        for (final sample in samples) {
          yield metric(
            'heart_rate',
            sample.time,
            sample.rate.inPerMinute,
            'bpm',
          );
        }
      case hc.SpeedSeriesRecord(:final samples):
        for (final sample in samples) {
          yield metric(
            'speed',
            sample.time,
            sample.speed.inKilometersPerHour,
            'km/h',
          );
        }
      case hc.OxygenSaturationRecord(:final saturation):
        yield metric('oxygen_saturation', start, saturation.asWhole, 'percent');
      case hc.RespiratoryRateRecord(:final rate):
        yield metric('respiratory_rate', start, rate.inPerMinute, 'rpm');
      case hc.HeightRecord(:final height):
        yield metric('height', start, height.inCentimeters, 'cm');
      case hc.BloodPressureRecord(:final systolic, :final diastolic):
        yield metric(
          'blood_pressure',
          start,
          systolic.inMillimetersOfMercury,
          'mmHg',
          secondary: diastolic.inMillimetersOfMercury,
        );
      case hc.ExerciseSessionRecord(:final exerciseType):
        yield metric(
          'exercise_session',
          start,
          exerciseType.index,
          'enum',
          endTime: end,
        );
      case hc.SleepSessionRecord(:final samples):
        yield metric('sleep_session', start, 1, 'session', endTime: end);
        for (final sample in samples) {
          yield metric(
            'sleep_stage',
            sample.startTime,
            sample.stageType.index,
            'enum',
            endTime: sample.endTime,
          );
        }
      default:
        return;
    }
  }

  String? _deviceJson(hc.Device? device) {
    if (device == null) return null;
    return jsonEncode({
      'type': device.type.name,
      'name': device.name,
      'manufacturer': device.manufacturer,
      'model': device.model,
      'hardwareVersion': device.hardwareVersion,
      'firmwareVersion': device.firmwareVersion,
      'softwareVersion': device.softwareVersion,
      'localIdentifier': device.localIdentifier,
      'udiDeviceIdentifier': device.udiDeviceIdentifier,
    });
  }

  Future<void> _createSessionAnalysis(
    Database database,
    hc.HealthConnector connector,
  ) async {
    final sessionRows = await database.query(
      'raw_records',
      where: 'type_id = ?',
      whereArgs: [hc.HealthDataType.exerciseSession.id],
    );
    for (final row in sessionRows) {
      final id = row['source_record_id'] as String;
      final response = await connector.readRecord(
        hc.HealthDataType.exerciseSession.readById(hc.HealthRecordId(id)),
      );
      if (response is! hc.ExerciseSessionRecord) continue;
      String? routeJson;
      try {
        final route = await connector.readExerciseRoute(response.id);
        if (route != null) {
          routeJson = jsonEncode({
            'locations': route.locations
                .map(
                  (location) => {
                    'time': location.time.millisecondsSinceEpoch,
                    'latitude': location.latitude,
                    'longitude': location.longitude,
                    'altitudeMeters': location.altitude?.inMeters,
                    'horizontalAccuracyMeters':
                        location.horizontalAccuracy?.inMeters,
                  },
                )
                .toList(),
          });
        }
      } catch (_) {
        routeJson = jsonEncode({'error': 'Route could not be read.'});
      }
      await database.insert('exercise_sessions', {
        'raw_record_id': row['id'],
        'exercise_type': response.exerciseType.name,
        'title': response.title,
        'notes': response.notes,
        'events_json': jsonEncode(
          response.events.map((event) => event.toString()).toList(),
        ),
        'route_json': routeJson,
      });
    }
  }

  Future<void> _createSummaryViews(Database database) async {
    await database.execute('''
      CREATE VIEW type_source_summary AS
      SELECT type_id, source_name, COUNT(*) AS record_count,
        MIN(start_time) AS first_start_time, MAX(end_time) AS last_end_time
      FROM raw_records
      GROUP BY type_id, source_name
    ''');
  }
}
