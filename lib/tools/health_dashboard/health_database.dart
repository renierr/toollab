import 'dart:math';

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
  ToolDatabase? _database;

  Future<ToolDatabase> _db() async {
    if (_database != null) return _database!;
    _database = await DatabaseService.instance.getToolDatabase(
      HealthDashboardTool.config.id,
    );
    await _database!.migrate(
      currentVersion: 1,
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
              UNIQUE(source, source_record_id)
            )
          ''');
        }
      },
    );
    return _database!;
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
    return rows.map(HealthRecord.fromMap).toList();
  }

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
    return {
      'distance': (row['distance'] as num?) ?? 0,
      'calories': (row['calories'] as num?) ?? 0,
      'duration': (row['duration'] as num?) ?? 0,
      'workouts': (row['workouts'] as num?) ?? 0,
    };
  }

  Future<int> allTimeSteps() async {
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(CAST(json_extract(value_json, '\$.count') AS INTEGER)), 0) AS steps
      FROM ${db.nameTable(_table)}
      WHERE deleted = 0 AND type = 'activity.steps'
    ''');
    return (rows.single['steps'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> syncRecords() async {
    final db = await _db();
    return db.query(_table, columns: ['id', 'updated_at', 'deleted']);
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

  Future<int> importBackup(String path) async {
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
      await db.transaction((txn) async {
        for (final row in rows) {
          final existing = await txn.query(
            _table,
            where: 'id = ? OR (source = ? AND source_record_id = ?)',
            whereArgs: [row['id'], row['source'], row['source_record_id']],
            limit: 1,
          );
          if (existing.isNotEmpty) continue;
          await txn.insert(_table, row);
          imported++;
        }
      });
      return imported;
    } finally {
      await backup.close();
    }
  }
}
