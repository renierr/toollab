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
  static const _legacyRecordsTable = 'records';
  static const _backupSchemaVersion = 9;
  static const syncCursorPrefix = 'sync_cursor_';

  /// Import watermark, cleared alongside the cursors on a canonical rebuild.
  static const healthConnectLastSyncKey = 'health_connect_last_sync';
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

  Future<void> resetAfterDatabaseImport() async {
    _database = null;
    _databaseFuture = null;
    _deviceId = _generateUuid();
    await DatabaseService.instance.setSetting(
      HealthDashboardTool.config.id,
      _deviceIdKey,
      _deviceId!,
    );
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
    var rebuiltCanonical = false;
    await database.migrate(
      currentVersion: 9,
      onMigrate: (txn, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(_legacyRecordsTable)} (
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
          final tableName = txn.nameTable(_legacyRecordsTable);
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
          final t = txn.nameTable(_legacyRecordsTable);
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
          final t = txn.nameTable(_legacyRecordsTable);
          await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_deleted_type_start ON $t (deleted, type, start_time)',
          );
        }
        if (oldVersion < 5) {
          await _createCanonicalSchema(txn);
        }
        if (oldVersion < 6) {
          await _createCanonicalImportCheckpointSchema(txn);
        }
        // Only canonical tables created by the pre-v9 schema lack these; the
        // current _createCanonicalSchema already declares them, so running the
        // ALTERs on a freshly created table would fail as a duplicate column.
        if (oldVersion >= 5 && oldVersion < 7) {
          await txn.execute(
            'ALTER TABLE ${txn.nameTable('health_source_records')} '
            'ADD COLUMN effective INTEGER NOT NULL DEFAULT 1',
          );
          await txn.execute(
            'ALTER TABLE ${txn.nameTable('health_source_records')} '
            'ADD COLUMN replaced_by_source_record_id TEXT',
          );
        }
        if (oldVersion >= 5 && oldVersion < 8) {
          for (final table in [
            'health_sources',
            'health_duplicate_candidates',
          ]) {
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(table)} '
              'ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
            );
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(table)} '
              'ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
        if (oldVersion < 9) {
          // v9 drops the importing device from canonical identity, so every
          // existing canonical primary key is stale and cannot be migrated in
          // place. Health Connect and Treadmill Control still hold the source
          // data, so the canonical set is rebuilt from them on the next import.
          if (oldVersion >= 5) await _rebuildCanonicalSchema(txn);
          await _dropLegacyRecordsTable(txn);
          rebuiltCanonical = true;
        }
      },
    );
    _database = database;
    if (rebuiltCanonical) await _clearSyncCursors();
    if (kDebugMode) {
      debugLog(
        '[HealthDatabase] Database open and migration completed in '
        '${stopwatch!.elapsedMilliseconds}ms',
      );
    }
    return database;
  }

  Future<void> _createCanonicalSchema(ToolDatabaseExecutor db) async {
    final sources = db.nameTable('health_sources');
    final sourceRecords = db.nameTable('health_source_records');
    final sessions = db.nameTable('health_sessions');
    final sessionDetails = db.nameTable('health_session_details');
    final samples = db.nameTable('health_metric_samples');
    final intervals = db.nameTable('health_interval_metrics');
    final candidates = db.nameTable('health_duplicate_candidates');
    await db.execute('''
      CREATE TABLE $sources (
        id TEXT PRIMARY KEY,
        package_name TEXT,
        importer_device_id TEXT,
        device_json TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(package_name)
      )
    ''');
    await db.execute('''
      CREATE TABLE $sourceRecords (
        id TEXT PRIMARY KEY,
        health_record_id TEXT NOT NULL,
        type_id TEXT NOT NULL,
        source_id TEXT NOT NULL REFERENCES $sources(id),
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        last_modified_time INTEGER,
        client_record_id TEXT,
        client_record_version INTEGER,
        recording_method TEXT,
        payload_json TEXT,
        source_kind TEXT,
        importer_device_id TEXT,
        effective INTEGER NOT NULL DEFAULT 1,
        replaced_by_source_record_id TEXT,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(health_record_id, type_id, source_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE $sessions (
        id TEXT PRIMARY KEY,
        source_record_id TEXT NOT NULL REFERENCES $sourceRecords(id),
        session_kind TEXT NOT NULL,
        session_type TEXT,
        title TEXT,
        notes TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(source_record_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE $sessionDetails (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES $sessions(id),
        detail_kind TEXT NOT NULL,
        start_time INTEGER,
        end_time INTEGER,
        sequence INTEGER NOT NULL DEFAULT 0,
        value_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE $samples (
        id TEXT PRIMARY KEY,
        source_record_id TEXT NOT NULL REFERENCES $sourceRecords(id),
        source_id TEXT,
        metric_type TEXT NOT NULL,
        time INTEGER NOT NULL,
        value REAL NOT NULL,
        value_secondary REAL,
        unit TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(metric_type, time, value, value_secondary)
      )
    ''');
    await db.execute('''
      CREATE TABLE $intervals (
        id TEXT PRIMARY KEY,
        source_record_id TEXT NOT NULL REFERENCES $sourceRecords(id),
        metric_type TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        value REAL NOT NULL,
        value_secondary REAL,
        unit TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(source_record_id, metric_type)
      )
    ''');
    await db.execute('''
      CREATE TABLE $candidates (
        id TEXT PRIMARY KEY,
        left_source_record_id TEXT NOT NULL REFERENCES $sourceRecords(id),
        right_source_record_id TEXT NOT NULL REFERENCES $sourceRecords(id),
        metric_type TEXT NOT NULL,
        time_delta_millis INTEGER,
        value_delta REAL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        UNIQUE(left_source_record_id, right_source_record_id, metric_type)
      )
    ''');
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_source_records_type_time')} '
      'ON $sourceRecords (type_id, start_time, end_time, deleted)',
    );
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_samples_metric_time')} '
      'ON $samples (metric_type, time, deleted)',
    );
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_intervals_metric_time')} '
      'ON $intervals (metric_type, start_time, end_time, deleted)',
    );
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_sessions_time')} '
      'ON $sessions (session_kind, start_time, end_time, deleted)',
    );
    await db.execute(
      'CREATE INDEX ${db.nameTable('idx_session_details_session')} '
      'ON $sessionDetails (session_id, detail_kind, sequence, deleted)',
    );
  }

  Future<void> _createCanonicalImportCheckpointSchema(
    ToolDatabaseExecutor db,
  ) async {
    final checkpoints = db.nameTable('health_import_checkpoints');
    await db.execute('''
      CREATE TABLE $checkpoints (
        importer_device_id TEXT NOT NULL,
        type_id TEXT NOT NULL,
        range_start INTEGER NOT NULL,
        range_end INTEGER NOT NULL,
        page_token TEXT,
        imported_count INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (importer_device_id, type_id)
      )
    ''');
  }

  /// Drops and recreates the canonical tables, clearing import checkpoints so
  /// the next sync re-imports everything. Treadmill Control storage is a
  /// separate database and is never touched.
  Future<void> _rebuildCanonicalSchema(ToolDatabaseExecutor db) async {
    for (final table in [
      'health_duplicate_candidates',
      'health_session_details',
      'health_sessions',
      'health_metric_samples',
      'health_interval_metrics',
      'health_source_records',
      'health_sources',
    ]) {
      await db.execute('DROP TABLE IF EXISTS ${db.nameTable(table)}');
    }
    await _createCanonicalSchema(db);
    await db.delete('health_import_checkpoints');
  }

  /// Sync cursors and the Health Connect watermark live in settings, not in the
  /// tool tables, so a canonical rebuild would otherwise leave them pointing
  /// past everything the emptied tables hold. A stale cursor makes the next sync
  /// ask only for changes since it and never repopulate - fatal on a device with
  /// no Health Connect. A stale watermark makes the next import resume from
  /// yesterday, so only a day of history lands in the rebuilt tables.
  Future<void> _clearSyncCursors() async {
    final settings = await DatabaseService.instance.getAllSettings(
      HealthDashboardTool.config.id,
    );
    for (final key in settings.keys) {
      if (!key.startsWith(syncCursorPrefix) &&
          key != healthConnectLastSyncKey) {
        continue;
      }
      await DatabaseService.instance.deleteSetting(
        HealthDashboardTool.config.id,
        key,
      );
      errorLog('[HealthDatabase] Cleared stale $key after canonical rebuild');
    }
  }

  /// The pre-canonical `records` cache has no readers or writers left; the
  /// canonical tables are the model and are rebuilt from Health Connect and
  /// Treadmill Control on the next import.
  Future<void> _dropLegacyRecordsTable(ToolDatabaseExecutor db) async {
    await db.execute(
      'DROP TABLE IF EXISTS ${db.nameTable(_legacyRecordsTable)}',
    );
    await db.delete('health_import_checkpoints');
  }

  Future<Map<String, Object?>?> canonicalImportCheckpoint(String typeId) async {
    final db = await _db();
    final devId = await deviceId;
    final rows = await db.query(
      'health_import_checkpoints',
      where: 'importer_device_id = ? AND type_id = ?',
      whereArgs: [devId, typeId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> saveCanonicalImportCheckpoint({
    required String typeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String? pageToken,
    required int importedCount,
    required bool completed,
  }) async {
    final db = await _db();
    final devId = await deviceId;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('health_import_checkpoints', {
      'importer_device_id': devId,
      'type_id': typeId,
      'range_start': rangeStart.millisecondsSinceEpoch,
      'range_end': rangeEnd.millisecondsSinceEpoch,
      'page_token': pageToken,
      'imported_count': importedCount,
      'completed_at': completed ? now : null,
      'updated_at': now,
      'deleted': 0,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Projects canonical rows into the legacy [HealthRecord] shape the UI reads.
  /// Records arriving over sync land only in the canonical tables, so every
  /// dashboard query must go through here or a device without Health Connect
  /// (Windows) renders nothing.
  static const _canonicalSelect = '''
    SELECT r.id AS id,
           COALESCE(r.source_kind, 'healthConnect') AS source,
           r.health_record_id AS source_record_id,
           r.type_id AS type,
           r.start_time AS start_time,
           r.end_time AS end_time,
           r.payload_json AS value_json,
           s.package_name AS source_name,
           r.replaced_by_source_record_id AS duplicate_of,
           r.importer_device_id AS device_id,
           r.effective AS aggregate_included,
           r.created_at AS created_at,
           r.updated_at AS updated_at,
           r.deleted AS deleted,
           r.synced AS synced
    FROM {records} r
    LEFT JOIN {sources} s ON s.id = r.source_id
  ''';

  String _canonicalQuery(ToolDatabase db, String where, {String? orderBy}) {
    final select = _canonicalSelect
        .replaceAll('{records}', db.nameTable('health_source_records'))
        .replaceAll('{sources}', db.nameTable('health_sources'));
    return '$select WHERE $where${orderBy == null ? '' : ' ORDER BY $orderBy'}';
  }

  Future<List<HealthRecord>> activeRecords() async {
    final db = await _db();
    final rows = await db.rawQuery(
      _canonicalQuery(
        db,
        'r.deleted = 0 AND r.effective = 1',
        orderBy: 'r.start_time DESC',
      ),
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  Future<List<HealthRecord>> activeRecordsSince(DateTime start) async {
    final db = await _db();
    final rows = await db.rawQuery(
      _canonicalQuery(
        db,
        'r.deleted = 0 AND r.effective = 1 AND r.end_time >= ?',
        orderBy: 'r.start_time DESC',
      ),
      [start.millisecondsSinceEpoch],
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
    final rows = await db.rawQuery(
      _canonicalQuery(
        db,
        'r.deleted = 0 AND r.effective = 1 AND r.type_id IN ($placeholders) '
        'AND r.end_time >= ? AND r.start_time < ?',
        orderBy: 'r.start_time DESC',
      ),
      [
        ...dashboardRecordTypes,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
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
        return db.rawQuery(
          '${_canonicalQuery(db, 'r.deleted = 0 AND r.effective = 1 AND r.type_id = ?', orderBy: 'r.start_time DESC')} LIMIT 50',
          [type],
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
    final rows = await db.rawQuery(
      '${_canonicalQuery(db, 'r.deleted = 0 AND r.effective = 1', orderBy: 'r.start_time DESC')} LIMIT ?',
      [limit],
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
    final where = <String>['r.deleted = 0', 'r.effective = 1'];
    final arguments = <Object?>[];
    if (type != null) {
      where.add('r.type_id = ?');
      arguments.add(type);
    } else if (typePrefix != null) {
      where.add('r.type_id LIKE ?');
      arguments.add('$typePrefix%');
    }
    final rows = await db.rawQuery(
      '${_canonicalQuery(db, where.join(' AND '), orderBy: 'r.start_time DESC')} LIMIT ? OFFSET ?',
      [...arguments, limit, offset],
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  Future<List<HealthRecord>> recordsOnDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final db = await _db();
    final rows = await db.rawQuery(
      _canonicalQuery(
        db,
        'r.deleted = 0 AND r.effective = 1 '
        'AND r.start_time >= ? AND r.start_time < ?',
        orderBy: 'r.start_time DESC',
      ),
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  Future<List<HealthRecord>> recordsForDay({
    required String type,
    required DateTime day,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final db = await _db();
    final rows = await db.rawQuery(
      _canonicalQuery(
        db,
        'r.deleted = 0 AND r.effective = 1 AND r.type_id = ? '
        'AND r.start_time >= ? AND r.start_time < ?',
        orderBy: 'r.start_time ASC',
      ),
      [type, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return compute(_parseRecords, rows);
  }

  Future<Map<String, num>> allTimeWorkoutSummary() async {
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CAST(json_extract(payload_json, '\$.distanceKm') AS REAL)), 0) AS distance,
        COALESCE(SUM(CAST(json_extract(payload_json, '\$.calories') AS REAL)), 0) AS calories,
        COALESCE(SUM(CASE
          WHEN type_id = 'workout.treadmill'
            THEN CAST(json_extract(payload_json, '\$.durationSeconds') AS INTEGER)
          ELSE (end_time - start_time) / 1000
        END), 0) AS duration,
        COUNT(*) AS workouts
      FROM ${db.nameTable('health_source_records')}
      WHERE deleted = 0 AND effective = 1 AND type_id LIKE 'workout.%'
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
      SELECT COALESCE(SUM(CAST(json_extract(payload_json, '\$.count') AS INTEGER)), 0) AS steps
      FROM ${db.nameTable('health_source_records')}
      WHERE deleted = 0 AND effective = 1 AND type_id = 'activity.steps'
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
        COALESCE(SUM(CAST(json_extract(payload_json, '\$.count') AS INTEGER)), 0) AS value
      FROM ${db.nameTable('health_source_records')}
      WHERE deleted = 0 AND effective = 1 AND type_id = 'activity.steps'
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
          WHEN type_id = 'heart.rate'
            THEN CAST(json_extract(payload_json, '\$.averageBpm') AS REAL)
          ELSE CAST(json_extract(payload_json, '\$.averageHeartRate') AS REAL)
        END) AS value
      FROM ${db.nameTable('health_source_records')}
      WHERE deleted = 0 AND effective = 1
        AND (type_id = 'heart.rate' OR type_id LIKE 'workout.%')
        AND start_time >= ? AND start_time < ?
        AND (CASE
          WHEN type_id = 'heart.rate'
            THEN CAST(json_extract(payload_json, '\$.averageBpm') AS REAL)
          ELSE CAST(json_extract(payload_json, '\$.averageHeartRate') AS REAL)
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

  Future<List<Map<String, dynamic>>> canonicalSyncRecords() async {
    final db = await _db();
    final tables = [
      'health_sources',
      'health_source_records',
      'health_sessions',
      'health_session_details',
      'health_metric_samples',
      'health_interval_metrics',
      'health_duplicate_candidates',
    ];
    final records = <Map<String, dynamic>>[];
    for (final table in tables) {
      final rows = await db.query(
        table,
        columns: ['id', 'updated_at', 'deleted'],
      );
      records.addAll(
        rows.map(
          (row) => {
            'id': row['id'],
            'updated_at': row['updated_at'],
            'deleted': row['deleted'] ?? 0,
          },
        ),
      );
    }
    return records;
  }

  /// Targeted lookup for incremental sync. The id prefix identifies the table,
  /// so only the tables actually referenced are queried instead of scanning all
  /// seven and filtering in Dart.
  Future<List<Map<String, dynamic>>> canonicalSyncRecordsByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final db = await _db();
    final byTable = <String, List<String>>{};
    for (final id in ids) {
      final table = _canonicalTableForId(id);
      if (table != null) byTable.putIfAbsent(table, () => []).add(id);
    }
    final records = <Map<String, dynamic>>[];
    for (final entry in byTable.entries) {
      final placeholders = List.filled(entry.value.length, '?').join(', ');
      final rows = await db.query(
        entry.key,
        columns: ['id', 'updated_at', 'deleted'],
        where: 'id IN ($placeholders)',
        whereArgs: entry.value,
      );
      records.addAll(
        rows.map(
          (row) => {
            'id': row['id'],
            'updated_at': row['updated_at'],
            'deleted': row['deleted'] ?? 0,
          },
        ),
      );
    }
    return records;
  }

  Future<Map<String, dynamic>?> canonicalSyncRecord(String id) async {
    final db = await _db();
    final table = _canonicalTableForId(id);
    if (table == null) return null;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final data = Map<String, dynamic>.from(rows.single);
    data['entityType'] = table;
    return data;
  }

  Future<void> finalizeCanonicalSync(String id, bool deleted) async {
    final table = _canonicalTableForId(id);
    if (table == null) return;
    final db = await _db();
    if (deleted) {
      await db.delete(table, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> savePulledCanonical({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final table = data['entityType'] as String? ?? _canonicalTableForId(id);
    if (table == null || !_canonicalSyncTables.contains(table)) return;
    final db = await _db();
    if (deleted) {
      await db.delete(table, where: 'id = ?', whereArgs: [id]);
      return;
    }
    final values = Map<String, Object?>.from(data)..remove('entityType');
    values['id'] = id;
    values['updated_at'] = updatedAt;
    values['synced'] = 1;
    await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static const _canonicalSyncTables = {
    'health_sources',
    'health_source_records',
    'health_sessions',
    'health_session_details',
    'health_metric_samples',
    'health_interval_metrics',
    'health_duplicate_candidates',
  };

  /// Entities written before the device-independent identity change carry the
  /// generation-less prefix. They are still on the backend and their ids still
  /// look valid, so they are rejected here by generation: an unrecognised
  /// generation resolves to no table and is ignored on pull. That makes an
  /// upgrade self-healing and removes any need to disable sync while devices
  /// migrate at different times.
  String? _canonicalTableForId(String id) {
    final prefix = id.split(':').first;
    if (!prefix.endsWith(_idGeneration)) return null;
    final kind = prefix.substring(0, prefix.length - _idGeneration.length);
    return switch (kind) {
      'source' => 'health_sources',
      'record' => 'health_source_records',
      'session' => 'health_sessions',
      'detail' => 'health_session_details',
      'sample' => 'health_metric_samples',
      'interval' => 'health_interval_metrics',
      'candidate' => 'health_duplicate_candidates',
      _ => null,
    };
  }

  /// Treadmill collection path. Writes canonically so collected workouts reach
  /// the dashboard and sync through the same model as Health Connect imports.
  Future<void> upsertCollected(HealthRecord record) async {
    final db = await _db();
    final devId = await deviceId;
    await db.transaction(
      (txn) => _upsertCanonicalRecord(txn, record.copyWith(deviceId: devId)),
    );
  }

  Future<void> upsertCanonicalCollected(Iterable<HealthRecord> records) async {
    final db = await _db();
    await db.transaction((txn) async {
      for (final record in records) {
        await _upsertCanonicalRecord(txn, record);
      }
    });
  }

  Future<void> upsertCanonicalPage({
    required String typeId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String? nextPageToken,
    required int importedCount,
    required bool completed,
    required Iterable<HealthRecord> records,
  }) async {
    final db = await _db();
    final devId = await deviceId;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final record in records) {
        await _upsertCanonicalRecord(txn, record.copyWith(deviceId: devId));
      }
      await txn.insert('health_import_checkpoints', {
        'importer_device_id': devId,
        'type_id': typeId,
        'range_start': rangeStart.millisecondsSinceEpoch,
        'range_end': rangeEnd.millisecondsSinceEpoch,
        'page_token': nextPageToken,
        'imported_count': importedCount,
        'completed_at': completed ? now : null,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> _upsertCanonicalRecord(
    ToolDatabaseExecutor db,
    HealthRecord record,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final packageName = record.sourceName ?? record.source.name;
    // Identity must not include the importing device: phone and tablet read the
    // same Health Connect record id for a session (624/626 exercise sessions in
    // the captured data), so a device-scoped id would store each one twice.
    // importer_device_id stays as provenance on the record, not in the key.
    final sourceId = _canonicalId('source', packageName);
    final sourceRecordId = _canonicalId(
      'record',
      '$packageName|${record.sourceRecordId}|${record.type}',
    );
    await db.insert('health_sources', {
      'id': sourceId,
      'package_name': packageName,
      'importer_device_id': record.deviceId,
      'created_at': now,
      'updated_at': now,
      'deleted': 0,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // No touch of updated_at here: the source row's contents do not change per
    // record, so this was one redundant write per imported record.
    await db.insert('health_source_records', {
      'id': sourceRecordId,
      'health_record_id': record.sourceRecordId,
      'type_id': record.type,
      'source_id': sourceId,
      'start_time': record.startTime,
      'end_time': record.endTime,
      'last_modified_time': record.updatedAt,
      'client_record_id': record.value['clientRecordId'] as String?,
      'payload_json': jsonEncode(record.value),
      'source_kind': record.source.name,
      'importer_device_id': record.deviceId,
      'created_at': record.createdAt,
      'updated_at': now,
      'deleted': record.deleted ? 1 : 0,
      'synced': 0,
      'effective': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _upsertCanonicalSession(db, sourceRecordId, record, now);
    await _upsertCanonicalSamples(db, sourceRecordId, record, now);
    await _upsertCanonicalInterval(db, sourceRecordId, record, now);
    await _createDuplicateCandidates(db, sourceRecordId, record, now);
  }

  Future<void> _upsertCanonicalSession(
    ToolDatabaseExecutor db,
    String sourceRecordId,
    HealthRecord record,
    int now,
  ) async {
    final isSleep = record.type == 'sleep.session';
    final isExercise = record.type.startsWith('workout.');
    if (!isSleep && !isExercise) return;
    final sessionId = _canonicalId('session', sourceRecordId);
    await db.insert('health_sessions', {
      'id': sessionId,
      'source_record_id': sourceRecordId,
      'session_kind': isSleep ? 'sleep' : 'exercise',
      'session_type': isExercise ? record.value['exerciseType'] : null,
      'title': record.value['title'],
      'notes': record.value['notes'],
      'start_time': record.startTime,
      'end_time': record.endTime,
      'updated_at': now,
      'deleted': record.deleted ? 1 : 0,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final details = isSleep
        ? record.value['stages'] as List? ?? const []
        : record.value['laps'] as List? ?? const [];
    for (var index = 0; index < details.length; index++) {
      final detail = Map<String, dynamic>.from(details[index] as Map);
      await db.insert('health_session_details', {
        'id': _canonicalId('detail', '$sessionId|$index'),
        'session_id': sessionId,
        'detail_kind': isSleep ? 'sleep_stage' : 'lap',
        'start_time': detail['startTime'],
        'end_time': detail['endTime'],
        'sequence': index,
        'value_json': jsonEncode(detail),
        'updated_at': now,
        'deleted': record.deleted ? 1 : 0,
        'synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _upsertCanonicalSamples(
    ToolDatabaseExecutor db,
    String sourceRecordId,
    HealthRecord record,
    int now,
  ) async {
    final rawSamples =
        record.value['samples'] ?? record.value['heartRateSamples'];
    if (rawSamples is! List || rawSamples.isEmpty) return;
    // Hoisted: this was recomputed, base64 and all, for every sample in a series.
    final sourceId = _canonicalId(
      'source',
      record.sourceName ?? record.source.name,
    );
    final deleted = record.deleted ? 1 : 0;
    // Inserting one row at a time costs a platform channel round trip per
    // sample, which is what a heart rate series import spends its time on.
    // Batched, an entire series is a single round trip.
    final batch = db.batch();
    var queued = 0;
    for (final rawSample in rawSamples) {
      final sample = Map<String, dynamic>.from(rawSample as Map);
      final time = sample['time'] as num?;
      final value =
          (sample['bpm'] ?? sample['speed'] ?? sample['value']) as num?;
      if (time == null || value == null) continue;
      final metricType = sample.containsKey('bpm')
          ? 'heart.rate'
          : sample.containsKey('speed')
          ? 'speed'
          : record.type;
      // Keyed on the measurement itself, not on the record that carried it: the
      // same physical sample re-read on another device arrives under a fresh
      // record id, so a record-scoped key would store it twice.
      batch.insert('health_metric_samples', {
        'id': _canonicalId('sample', '$metricType|$time|$value'),
        'source_record_id': sourceRecordId,
        'source_id': sourceId,
        'metric_type': metricType,
        'time': time.toInt(),
        'value': value.toDouble(),
        'unit': metricType == 'heart.rate' ? 'bpm' : 'km/h',
        'updated_at': now,
        'deleted': deleted,
        'synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      queued++;
    }
    if (queued > 0) await batch.commit(noResult: true);
  }

  Future<void> _upsertCanonicalInterval(
    ToolDatabaseExecutor db,
    String sourceRecordId,
    HealthRecord record,
    int now,
  ) async {
    final value = _primaryValue(record);
    if (value == null) return;
    await db.insert('health_interval_metrics', {
      'id': _canonicalId('interval', '$sourceRecordId|${record.type}'),
      'source_record_id': sourceRecordId,
      'metric_type': record.type,
      'start_time': record.startTime,
      'end_time': record.endTime,
      'value': value,
      'unit': _unitFor(record),
      'updated_at': now,
      'deleted': record.deleted ? 1 : 0,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _createDuplicateCandidates(
    ToolDatabaseExecutor db,
    String sourceRecordId,
    HealthRecord record,
    int now,
  ) async {
    final value = _primaryValue(record);
    if (value == null) return;
    // Dense series carry their measurements in samples, which already collapse
    // on (metric_type, time, value). Pairing them off against every other record
    // of the same type finds nothing and makes the import quadratic.
    if ((record.value['samples'] ?? record.value['heartRateSamples']) is List) {
      return;
    }
    final sourceRecords = db.nameTable('health_source_records');
    final intervals = db.nameTable('health_interval_metrics');
    // Ranges are expressed as BETWEEN rather than ABS(...) <= so the query can
    // seek idx_source_records_type_time. ABS() is not sargable, which turned
    // this into a full scan of every record sharing the type, per record.
    const window = 5000;
    final matches = await db.rawQuery(
      '''SELECT records.id, records.source_id, records.start_time,
           records.end_time, records.client_record_id,
           records.last_modified_time, intervals.value AS metric_value
         FROM $sourceRecords records
         LEFT JOIN $intervals intervals ON intervals.source_record_id = records.id
           AND intervals.metric_type = records.type_id AND intervals.deleted = 0
         WHERE records.type_id = ? AND records.id != ? AND records.deleted = 0
           AND records.start_time BETWEEN ? AND ?
           AND records.end_time BETWEEN ? AND ?''',
      [
        record.type,
        sourceRecordId,
        record.startTime - window,
        record.startTime + window,
        record.endTime - window,
        record.endTime + window,
      ],
    );
    final ownSourceId = _canonicalId(
      'source',
      record.sourceName ?? record.source.name,
    );
    final ownToken = _clientIdToken(record.value['clientRecordId'] as String?);
    for (final match in matches) {
      if (match['source_id'] == ownSourceId) continue;
      final otherId = match['id'] as String;
      final left = sourceRecordId.compareTo(otherId) < 0
          ? sourceRecordId
          : otherId;
      final right = left == sourceRecordId ? otherId : sourceRecordId;
      final otherValue = match['metric_value'] as num?;
      // A republishing app rewrites another app's record under its own package
      // but keeps the originator's identifier embedded in the client record id.
      // Comparing the trailing numeric token detects that generically, without
      // knowing any vendor package name.
      final mirrored =
          ownToken != null &&
          ownToken == _clientIdToken(match['client_record_id'] as String?);
      await db.insert('health_duplicate_candidates', {
        'id': _canonicalId('candidate', '$left|$right|${record.type}'),
        'left_source_record_id': left,
        'right_source_record_id': right,
        'metric_type': record.type,
        'time_delta_millis': (record.startTime - (match['start_time'] as int))
            .abs(),
        'value_delta': otherValue is num ? (value - otherValue).abs() : null,
        'status': mirrored ? 'mirror' : 'pending',
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (!mirrored) continue;
      // An originator writes a measurement before anything can republish it, so
      // the later-written side of a confirmed mirror is the copy. This is
      // derived from the records themselves rather than a vendor preference;
      // the per-type source preference in settings overrides it for display.
      final otherModified = match['last_modified_time'] as int?;
      final loser = (otherModified != null && otherModified > record.updatedAt)
          ? otherId
          : (otherModified != null && otherModified < record.updatedAt)
          ? sourceRecordId
          : right;
      final winner = loser == sourceRecordId ? otherId : sourceRecordId;
      await db.update(
        'health_source_records',
        {'effective': 0, 'replaced_by_source_record_id': winner, 'synced': 0},
        where: 'id = ?',
        whereArgs: [loser],
      );
    }
  }

  /// Trailing digit run of a client record id, e.g. `Sleep_1758062520000` and
  /// `1758062520000` both yield `1758062520000`. Vendor-neutral on purpose.
  static String? _clientIdToken(String? clientRecordId) {
    if (clientRecordId == null) return null;
    final match = RegExp(r'(\d{8,})$').firstMatch(clientRecordId);
    return match?.group(1);
  }

  /// Bumped whenever canonical identity changes, so entities from an older
  /// scheme can never be pulled back into the current tables.
  static const _idGeneration = '2';

  static String _canonicalId(String prefix, String value) =>
      '$prefix$_idGeneration:'
      '${base64Url.encode(utf8.encode(value)).replaceAll('=', '')}';

  static double? _primaryValue(HealthRecord record) {
    const keys = [
      'count',
      'kilograms',
      'bpm',
      'averageBpm',
      'percent',
      'rmssdMs',
      'respiratoryRate',
      'distanceKm',
      'calories',
    ];
    for (final key in keys) {
      final value = record.value[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static String _unitFor(HealthRecord record) => switch (record.type) {
    'activity.steps' => 'count',
    'body.weight' => 'kg',
    'heart.resting' || 'heart.rate' => 'bpm',
    _ when record.value.containsKey('percent') => 'percent',
    _ when record.value.containsKey('distanceKm') => 'km',
    _ when record.value.containsKey('calories') => 'kcal',
    _ => 'count',
  };

  /// Tool-scoped backup contents. Import checkpoints are deliberately absent:
  /// they are device-local resume state, and restoring them would claim data
  /// was already imported on a device that never read it.
  static const _backupTables = [
    'health_sources',
    'health_source_records',
    'health_sessions',
    'health_session_details',
    'health_metric_samples',
    'health_interval_metrics',
    'health_duplicate_candidates',
  ];
  static const _backupMarkerTable = 'health_backup_meta';

  /// Copies this tool's tables straight into a new database file. The work runs
  /// inside SQLite, so nothing is materialised as Dart objects and the cost is
  /// bounded by disk rather than by record count.
  Future<String> exportBackup({
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = await _db();
    final path = await TempFileManager.createFile('health_dashboard_backup.db');
    final file = File(path);
    // ATTACH expects to create the file itself; TempFileManager may have
    // already made an empty placeholder.
    if (await file.exists()) await file.delete();
    final total = _backupTables.length;
    onProgress?.call(0, total);
    await db.execute('ATTACH DATABASE ? AS backup', [path]);
    try {
      await db.execute(
        'CREATE TABLE backup.$_backupMarkerTable '
        '(tool_id TEXT NOT NULL, schema_version INTEGER NOT NULL, '
        'exported_at INTEGER NOT NULL)',
      );
      await db
          .execute('INSERT INTO backup.$_backupMarkerTable VALUES (?, ?, ?)', [
            HealthDashboardTool.config.id,
            _backupSchemaVersion,
            DateTime.now().millisecondsSinceEpoch,
          ]);
      var processed = 0;
      for (final table in _backupTables) {
        await db.execute(
          'CREATE TABLE backup.$table AS SELECT * FROM ${db.nameTable(table)}',
        );
        onProgress?.call(++processed, total);
      }
    } finally {
      await db.execute('DETACH DATABASE backup');
    }
    return path;
  }

  /// Merges a tool backup back in. Rows are matched on their canonical primary
  /// key, so re-importing the same backup is idempotent.
  Future<int> importBackup(
    String path, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final probe = await openDatabase(path, readOnly: true);
    try {
      final marker = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [_backupMarkerTable],
      );
      if (marker.isEmpty) {
        throw const FormatException('Not a Health Dashboard backup.');
      }
    } finally {
      await probe.close();
    }
    final db = await _db();
    final total = _backupTables.length;
    var processed = 0;
    var imported = 0;
    onProgress?.call(0, total);
    await db.execute('ATTACH DATABASE ? AS backup', [path]);
    try {
      for (final table in _backupTables) {
        final present = await db.rawQuery(
          "SELECT name FROM backup.sqlite_master WHERE type = 'table' AND name = ?",
          [table],
        );
        if (present.isNotEmpty) {
          imported += await db.rawUpdate(
            'INSERT OR REPLACE INTO ${db.nameTable(table)} '
            'SELECT * FROM backup.$table',
          );
        }
        onProgress?.call(++processed, total);
      }
    } finally {
      await db.execute('DETACH DATABASE backup');
    }
    return imported;
  }

  Future<void> purgeHealthConnectCache() async {
    final db = await _db();
    final devId = await deviceId;
    await db.transaction((txn) async {
      final sourceRecords = txn.nameTable('health_source_records');
      final sessions = txn.nameTable('health_sessions');
      final details = txn.nameTable('health_session_details');
      final samples = txn.nameTable('health_metric_samples');
      final intervals = txn.nameTable('health_interval_metrics');
      final candidates = txn.nameTable('health_duplicate_candidates');
      // Sources are shared across devices now, so "this device's import" is
      // scoped by the record's importer, never by the source row. Treadmill
      // records are excluded: only Health Connect is re-imported afterwards, so
      // dropping them here would lose data nothing in this flow restores.
      const healthConnectOnly =
          "importer_device_id = ? "
          "AND COALESCE(source_kind, 'healthConnect') = 'healthConnect'";
      final localRecords =
          'SELECT id FROM $sourceRecords WHERE $healthConnectOnly';
      await txn.rawDelete(
        'DELETE FROM $candidates WHERE left_source_record_id IN ($localRecords) '
        'OR right_source_record_id IN ($localRecords)',
        [devId, devId],
      );
      await txn.rawDelete(
        'DELETE FROM $details WHERE session_id IN '
        '(SELECT id FROM $sessions WHERE source_record_id IN ($localRecords))',
        [devId],
      );
      await txn.rawDelete(
        'DELETE FROM $sessions WHERE source_record_id IN ($localRecords)',
        [devId],
      );
      await txn.rawDelete(
        'DELETE FROM $samples WHERE source_record_id IN ($localRecords)',
        [devId],
      );
      await txn.rawDelete(
        'DELETE FROM $intervals WHERE source_record_id IN ($localRecords)',
        [devId],
      );
      await txn.rawDelete(
        'DELETE FROM $sourceRecords WHERE $healthConnectOnly',
        [devId],
      );
      // Raw name: delete() namespaces its argument, so passing a nameTable()
      // result here would resolve to tool_<id>_tool_<id>_… and throw.
      await txn.delete(
        'health_import_checkpoints',
        where: 'importer_device_id = ?',
        whereArgs: [devId],
      );
    });
  }

  Future<String> exportHealthConnectJson() async {
    final db = await _db();
    final rows = await db.rawQuery(
      _canonicalQuery(
        db,
        "r.deleted = 0 AND COALESCE(r.source_kind, 'healthConnect') = 'healthConnect'",
        orderBy: 'r.start_time DESC',
      ),
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
