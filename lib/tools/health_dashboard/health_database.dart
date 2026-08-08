import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'health_record.dart';

class HealthDatabase {
  HealthDatabase._();

  static final HealthDatabase instance = HealthDatabase._();
  static const _table = 'records';
  static const _backupTable = 'health_records';
  static const _deviceIdKey = 'health_device_uuid';
  static const dashboardRecordTypes = [
    'body.weight',
    'heart.resting',
    'sleep.session',
    'workout.treadmill',
    'workout.health_connect',
    'health.heart_rate_variability_rmssd',
    'health.oxygen_saturation',
    'health.respiratory_rate',
    'health.body_fat_percentage',
  ];
  static const _latestDashboardTypes = [
    'body.weight',
    'heart.resting',
    'sleep.session',
    'health.heart_rate_variability_rmssd',
    'health.oxygen_saturation',
    'health.respiratory_rate',
    'health.body_fat_percentage',
  ];
  ToolDatabase? _database;
  Future<ToolDatabase>? _databaseFuture;
  String? _deviceId;

  Future<String> get deviceId async {
    if (_deviceId != null) return _deviceId!;
    _deviceId = await DatabaseService.instance.getSetting(
      HealthDashboardTool.config.id,
      _deviceIdKey,
    );
    if (_deviceId == null) {
      _deviceId = _generateUuid();
      await DatabaseService.instance.setSetting(
        HealthDashboardTool.config.id,
        _deviceIdKey,
        _deviceId!,
      );
    }
    return _deviceId!;
  }

  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<ToolDatabase> _db() async {
    if (_database != null) return _database!;
    return _databaseFuture ??= _openDatabase();
  }

  Future<ToolDatabase> _openDatabase() async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final database = await DatabaseService.instance.getToolDatabase(
      HealthDashboardTool.config.id,
    );
    final devId = await deviceId;
    await database.migrate(
      currentVersion: 4,
      onMigrate: (txn, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(_table)} (
              id TEXT PRIMARY KEY,
              source TEXT NOT NULL,
              source_record_id TEXT NOT NULL,
              type TEXT NOT NULL,
              start_time INTEGER NOT NULL,
              end_time INTEGER NOT NULL,
              value_json TEXT NOT NULL,
              source_name TEXT,
              duplicate_of TEXT,
              aggregate_included INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted INTEGER NOT NULL DEFAULT 0,
              synced INTEGER NOT NULL DEFAULT 0,
              device_id TEXT,
              UNIQUE(source, source_record_id)
            )
          ''');
        }
        if (oldVersion >= 1 && oldVersion < 2) {
          final tableName = txn.nameTable(_table);
          await txn.execute('ALTER TABLE $tableName ADD COLUMN device_id TEXT');
          await txn.execute(
            "UPDATE $tableName SET device_id = ? WHERE source = 'healthConnect'",
            [devId],
          );
          errorLog(
            '[HealthDatabase] Backfilled device_id=$devId on existing healthConnect records',
          );
        }
        if (oldVersion < 3) {
          final t = txn.nameTable(_table);
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_deleted_start ON $t (deleted, start_time)',
          );
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_deleted_end ON $t (deleted, end_time)',
          );
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_source_device ON $t (source, device_id)',
          );
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_deleted_type ON $t (deleted, type)',
          );
        }
        if (oldVersion < 4) {
          final t = txn.nameTable(_table);
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_deleted_type_start ON $t (deleted, type, start_time)',
          );
        }
      },
    );
    _database = database;
    if (kDebugMode) {
      debugLog(
        '[HealthDatabase] Database open and migration completed in '
        '${stopwatch!.elapsedMilliseconds}ms',
      );
    }
    return database;
  }

  Future<List<HealthRecord>> activeRecords() async {
    final db = await _db();
    final rows = await db.query(
      _table,
      where: 'deleted = 0',
      orderBy: 'start_time DESC',
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  Future<List<HealthRecord>> activeRecordsSince(DateTime start) async {
    final db = await _db();
    final rows = await db.query(
      _table,
      where: 'deleted = 0 AND end_time >= ?',
      whereArgs: [start.millisecondsSinceEpoch],
      orderBy: 'start_time DESC',
    );
    return compute(_parseRecords, rows);
  }

  Future<List<HealthRecord>> dashboardRecords({
    required DateTime start,
    required DateTime end,
  }) async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final db = await _db();
    final placeholders = List.filled(
      dashboardRecordTypes.length,
      '?',
    ).join(', ');
    final rows = await db.query(
      _table,
      where:
          'deleted = 0 AND type IN ($placeholders) '
          'AND end_time >= ? AND start_time < ?',
      whereArgs: [
        ...dashboardRecordTypes,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'start_time DESC',
    );
    final queryMs = stopwatch?.elapsedMilliseconds;
    final records = await compute(_parseRecords, rows);
    if (kDebugMode) {
      debugLog(
        '[HealthDatabase] Dashboard range: ${rows.length} rows, '
        'query ${queryMs}ms, parse '
        '${stopwatch!.elapsedMilliseconds - queryMs!}ms',
      );
    }
    return records;
  }

  Future<List<HealthRecord>> latestDashboardRecords() async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final db = await _db();
    final results = await Future.wait(
      _latestDashboardTypes.map((type) {
        return db.query(
          _table,
          where: 'deleted = 0 AND type = ?',
          whereArgs: [type],
          orderBy: 'start_time DESC',
          limit: 50,
        );
      }),
    );
    final rows = results.expand((rows) => rows).toList();
    final queryMs = stopwatch?.elapsedMilliseconds;
    final records = await compute(_parseRecords, rows);
    if (kDebugMode) {
      debugLog(
        '[HealthDatabase] Latest dashboard values: ${rows.length} rows, '
        'query ${queryMs}ms, parse '
        '${stopwatch!.elapsedMilliseconds - queryMs!}ms',
      );
    }
    return records;
  }

  static List<HealthRecord> _parseRecords(List<Map<String, dynamic>> rows) =>
      rows.map(HealthRecord.fromMap).toList();

  Future<List<HealthRecord>> recentRecords({int limit = 200}) async {
    final db = await _db();
    final rows = await db.query(
      _table,
      where: 'deleted = 0',
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  Future<List<HealthRecord>> recordsPage({
    String? typePrefix,
    String? type,
    int offset = 0,
    int limit = 100,
  }) async {
    final db = await _db();
    final where = <String>['deleted = 0'];
    final arguments = <Object?>[];
    if (type != null) {
      where.add('type = ?');
      arguments.add(type);
    } else if (typePrefix != null) {
      where.add('type LIKE ?');
      arguments.add('$typePrefix%');
    }
    final rows = await db.query(
      _table,
      where: where.join(' AND '),
      whereArgs: arguments,
      orderBy: 'start_time DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  Future<List<HealthRecord>> recordsOnDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final db = await _db();
    final rows = await db.query(
      _table,
      where: 'deleted = 0 AND start_time >= ? AND start_time < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'start_time DESC',
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  Future<Map<String, num>> allTimeWorkoutSummary() async {
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CAST(json_extract(value_json, '\$.distanceKm') AS REAL)), 0) AS distance,
        COALESCE(SUM(CAST(json_extract(value_json, '\$.calories') AS REAL)), 0) AS calories,
        COALESCE(SUM(CASE
          WHEN type = 'workout.treadmill'
            THEN CAST(json_extract(value_json, '\$.durationSeconds') AS INTEGER)
          ELSE (end_time - start_time) / 1000
        END), 0) AS duration,
        COUNT(*) AS workouts
      FROM ${db.nameTable(_table)}
      WHERE deleted = 0 AND type LIKE 'workout.%'
    ''');
    final row = rows.single;
    final summary = {
      'distance': (row['distance'] as num?) ?? 0,
      'calories': (row['calories'] as num?) ?? 0,
      'duration': (row['duration'] as num?) ?? 0,
      'workouts': (row['workouts'] as num?) ?? 0,
    };
    return summary;
  }

  Future<int> allTimeSteps() async {
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(json_extract(value_json, '\$.count') AS INTEGER)), 0) AS steps
      FROM ${db.nameTable(_table)}
      WHERE deleted = 0 AND type = 'activity.steps'
    ''');
    final steps = (rows.single['steps'] as num?)?.toInt() ?? 0;
    return steps;
  }

  Future<Map<String, int>> dailyStepTotals({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _db();
    final rows = await db.rawQuery(
      '''
      SELECT
        strftime('%Y-%m-%d', start_time / 1000, 'unixepoch', 'localtime') AS day,
        COALESCE(SUM(CAST(json_extract(value_json, '\$.count') AS INTEGER)), 0) AS value
      FROM ${db.nameTable(_table)}
      WHERE deleted = 0 AND type = 'activity.steps'
        AND start_time >= ? AND start_time < ?
      GROUP BY day
    ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return {
      for (final row in rows)
        row['day'] as String: (row['value'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, double>> dailyHeartRateAverages({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _db();
    final rows = await db.rawQuery(
      '''
      SELECT
        strftime('%Y-%m-%d', start_time / 1000, 'unixepoch', 'localtime') AS day,
        AVG(CASE
          WHEN type = 'heart.rate'
            THEN CAST(json_extract(value_json, '\$.averageBpm') AS REAL)
          ELSE CAST(json_extract(value_json, '\$.averageHeartRate') AS REAL)
        END) AS value
      FROM ${db.nameTable(_table)}
      WHERE deleted = 0 AND (type = 'heart.rate' OR type LIKE 'workout.%')
        AND start_time >= ? AND start_time < ?
        AND (CASE
          WHEN type = 'heart.rate'
            THEN CAST(json_extract(value_json, '\$.averageBpm') AS REAL)
          ELSE CAST(json_extract(value_json, '\$.averageHeartRate') AS REAL)
        END) > 0
      GROUP BY day
    ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return {
      for (final row in rows)
        row['day'] as String: (row['value'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> syncRecords() async {
    final db = await _db();
    return db.query(_table, columns: ['id', 'updated_at', 'deleted']);
  }

  Future<List<Map<String, dynamic>>> syncRecordsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final db = await _db();
    final placeholders = List.filled(ids.length, '?').join(', ');
    return db.query(
      _table,
      columns: ['id', 'updated_at', 'deleted'],
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<List<Map<String, dynamic>>> pendingSyncRecords() async {
    final db = await _db();
    return db.query(
      _table,
      columns: ['id', 'updated_at', 'deleted'],
      where: 'synced = 0',
    );
  }

  Future<HealthRecord?> record(String id) async {
    final db = await _db();
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : HealthRecord.fromMap(rows.first);
  }

  Future<void> upsertCollected(HealthRecord record) async {
    final db = await _db();
    final rows = await db.query(
      _table,
      where: 'source = ? AND source_record_id = ?',
      whereArgs: [record.source.name, record.sourceRecordId],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert(_table, record.toMap());
      return;
    }
    final existing = HealthRecord.fromMap(rows.first);
    final updated = record.copyWith(
      updatedAt: max(record.updatedAt, existing.updatedAt + 1),
      synced: false,
    );
    await db.update(
      _table,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [existing.id],
    );
  }

  Future<void> savePulled(HealthRecord record) async {
    final db = await _db();
    final local = await this.record(record.id);
    if (local != null && local.updatedAt > record.updatedAt) return;
    final values = record.copyWith(synced: true).toMap();
    if (local == null) {
      await db.insert(_table, values);
    } else {
      await db.update(_table, values, where: 'id = ?', whereArgs: [record.id]);
    }
  }

  Future<void> finalizeSync(String id, bool deleted) async {
    final db = await _db();
    if (deleted) {
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(_table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<String> exportBackup() async {
    final records = await activeRecords();
    final path = await TempFileManager.createFile('health_dashboard_backup.db');
    final backup = await openDatabase(path);
    try {
      await backup.execute('''
        CREATE TABLE $_backupTable (
          id TEXT PRIMARY KEY,
          source TEXT NOT NULL,
          source_record_id TEXT NOT NULL,
          type TEXT NOT NULL,
          start_time INTEGER NOT NULL,
          end_time INTEGER NOT NULL,
          value_json TEXT NOT NULL,
          source_name TEXT,
          duplicate_of TEXT,
          aggregate_included INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted INTEGER NOT NULL,
          synced INTEGER NOT NULL,
          UNIQUE(source, source_record_id)
        )
      ''');
      final batch = backup.batch();
      for (final record in records) {
        batch.insert(_backupTable, record.toMap());
      }
      await batch.commit(noResult: true);
    } finally {
      await backup.close();
    }
    return path;
  }

  Future<int> importBackup(
    String path, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final backup = await openDatabase(path, readOnly: true);
    try {
      final tables = await backup.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [_backupTable],
      );
      if (tables.isEmpty) {
        throw const FormatException('Not a Health Dashboard backup.');
      }
      final rows = await backup.query(_backupTable);
      final db = await _db();
      var imported = 0;
      var processed = 0;
      onProgress?.call(processed, rows.length);
      await db.transaction((txn) async {
        for (final row in rows) {
          final existing = await txn.query(
            _table,
            where: 'id = ? OR (source = ? AND source_record_id = ?)',
            whereArgs: [row['id'], row['source'], row['source_record_id']],
            limit: 1,
          );
          if (existing.isEmpty) {
            await txn.insert(_table, row);
            imported++;
          }
          processed++;
          if (processed % 100 == 0 || processed == rows.length) {
            onProgress?.call(processed, rows.length);
          }
        }
      });
      return imported;
    } finally {
      await backup.close();
    }
  }

  Future<void> purgeHealthConnectCache() async {
    final db = await _db();
    final devId = await deviceId;
    await db.delete(
      _table,
      where: "source = 'healthConnect' AND device_id = ?",
      whereArgs: [devId],
    );
  }

  Future<String> exportHealthConnectJson() async {
    final db = await _db();
    final rows = await db.query(
      _table,
      where: "source = 'healthConnect' AND deleted = 0",
      orderBy: 'start_time DESC',
    );
    final records = rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      try {
        map['value_json'] = jsonDecode(row['value_json'] as String);
      } catch (_) {}
      return map;
    }).toList();

    final path = await TempFileManager.createFile(
      'health_connect_export_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await File(
      path,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(records));
    return path;
  }
}
