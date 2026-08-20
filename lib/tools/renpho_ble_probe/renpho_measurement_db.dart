import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'renpho_measurement.dart';

class RenphoMeasurementDb {
  RenphoMeasurementDb._();
  static final instance = RenphoMeasurementDb._();
  static const table = 'measurements';

  ToolDatabase? _db;

  Future<ToolDatabase> _database() async {
    if (_db != null) return _db!;
    _db = await DatabaseService.instance.getToolDatabase(
      RenphoBleProbeTool.config.id,
    );
    try {
      await _db!.migrate(
        currentVersion: 3,
        onMigrate: (txn, oldVersion, _) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(table)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                uid TEXT NOT NULL UNIQUE,
                measured_at INTEGER NOT NULL,
                weight_kg REAL NOT NULL,
                bmi REAL NOT NULL,
                body_fat_percent REAL NOT NULL,
                muscle_percent REAL NOT NULL,
                visceral_fat INTEGER NOT NULL,
                impedance_json TEXT NOT NULL,
                packet_hex TEXT NOT NULL,
                health_connect_published_at INTEGER NOT NULL DEFAULT 0
              )
            ''');
          }
          if (oldVersion < 2) {
            const columns = {
              'stored_record': 'INTEGER NOT NULL DEFAULT 0',
              'profile_name': "TEXT NOT NULL DEFAULT 'User'",
              'profile_sex': "TEXT NOT NULL DEFAULT 'male'",
              'profile_height_cm': 'REAL NOT NULL DEFAULT 175',
              'profile_age': 'INTEGER NOT NULL DEFAULT 0',
              'synced': 'INTEGER NOT NULL DEFAULT 0',
              'deleted': 'INTEGER NOT NULL DEFAULT 0',
              'created_at': 'INTEGER NOT NULL DEFAULT 0',
              'updated_at': 'INTEGER NOT NULL DEFAULT 0',
            };
            for (final entry in columns.entries) {
              await txn.execute(
                'ALTER TABLE ${txn.nameTable(table)} '
                'ADD COLUMN ${entry.key} ${entry.value}',
              );
            }
            // Rows written before sync existed have no timestamps, and a zero
            // updated_at would make the backend treat every one of them as the
            // loser of any conflict.
            await txn.execute(
              'UPDATE ${txn.nameTable(table)} '
              'SET created_at = measured_at, updated_at = measured_at '
              'WHERE updated_at = 0',
            );
          }
          if (oldVersion < 3) {
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(table)} '
              'ADD COLUMN imported INTEGER NOT NULL DEFAULT 0',
            );
          }
        },
      );
    } catch (e) {
      errorLog('[RenphoScale] Migration failed: $e');
    }
    return _db!;
  }

  String newUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Stores a scan. Returns null when a reading for the same minute is already
  /// on file — the scale replays its stored records on every connect, so
  /// without this every session would duplicate the backlog.
  Future<RenphoMeasurement?> insert(RenphoMeasurement measurement) async {
    final db = await _database();
    final existing = await db.query(
      table,
      where: 'measured_at BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [
        measurement.measuredAt.millisecondsSinceEpoch - 30000,
        measurement.measuredAt.millisecondsSinceEpoch + 30000,
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final row = measurement.copyWith(
      uid: measurement.uid.isEmpty ? newUid() : measurement.uid,
      createdAt: now,
      updatedAt: now,
      synced: false,
    );
    final id = await db.insert(
      table,
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return row.copyWith(id: id);
  }

  Future<List<RenphoMeasurement>> all({int? limit}) async {
    final db = await _database();
    final rows = await db.query(
      table,
      where: 'deleted = 0',
      orderBy: 'measured_at DESC',
      limit: limit,
    );
    return rows.map(RenphoMeasurement.fromMap).toList();
  }

  /// Just the timestamps, newest first. One indexed integer column is cheap
  /// enough to read whole, and it is all the month index needs — the rows
  /// themselves are only loaded for the month the user opens.
  Future<List<int>> timestamps() async {
    final db = await _database();
    final rows = await db.query(
      table,
      columns: const ['measured_at'],
      where: 'deleted = 0',
      orderBy: 'measured_at DESC',
    );
    return rows.map((row) => row['measured_at'] as int).toList();
  }

  /// Rows in `[from, to)`, newest first.
  Future<List<RenphoMeasurement>> between(DateTime from, DateTime to) async {
    final db = await _database();
    final rows = await db.query(
      table,
      where: 'deleted = 0 AND measured_at >= ? AND measured_at < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'measured_at DESC',
    );
    return rows.map(RenphoMeasurement.fromMap).toList();
  }

  Future<RenphoMeasurement?> byUid(String uid) async {
    final db = await _database();
    final rows = await db.query(
      table,
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? null : RenphoMeasurement.fromMap(rows.first);
  }

  /// Marks a scan deleted rather than removing it, so the backend learns about
  /// the deletion on the next sync.
  Future<void> softDelete(String uid) async {
    final db = await _database();
    await db.update(
      table,
      {
        'deleted': 1,
        'synced': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<void> hardDelete(String uid) async {
    final db = await _database();
    await db.delete(table, where: 'uid = ?', whereArgs: [uid]);
  }

  // Health Connect bookkeeping.

  Future<List<RenphoMeasurement>> healthConnectPending() async {
    final db = await _database();
    final rows = await db.query(
      table,
      where: 'deleted = 0 AND health_connect_published_at < updated_at',
      orderBy: 'measured_at ASC',
    );
    return rows.map(RenphoMeasurement.fromMap).toList();
  }

  /// Bumped without touching `updated_at`, so publishing does not make the row
  /// look edited to the backend sync.
  Future<void> markHealthConnectPublished(RenphoMeasurement measurement) async {
    final db = await _database();
    await db.update(
      table,
      {'health_connect_published_at': DateTime.now().millisecondsSinceEpoch},
      where: 'uid = ?',
      whereArgs: [measurement.uid],
    );
  }

  Future<int> resetHealthConnectPublished() async {
    final db = await _database();
    return db.update(table, {'health_connect_published_at': 0});
  }

  Future<int?> earliestMeasurement() async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT MIN(measured_at) AS earliest FROM ${db.nameTable(table)}',
    );
    return rows.isEmpty ? null : (rows.first['earliest'] as num?)?.toInt();
  }

  // Backend sync.

  Future<List<Map<String, Object?>>> syncRecords() async {
    final db = await _database();
    return db.query(table, columns: ['uid', 'updated_at', 'deleted']);
  }

  Future<void> savePulled(RenphoMeasurement measurement) async {
    final db = await _database();
    final existing = await byUid(measurement.uid);
    final row = measurement.copyWith(synced: true);
    if (existing == null) {
      await db.insert(
        table,
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }
    await db.update(
      table,
      row.copyWith(id: existing.id).toMap(),
      where: 'uid = ?',
      whereArgs: [measurement.uid],
    );
  }

  Future<void> markSynced(String uid) async {
    final db = await _database();
    await db.update(table, {'synced': 1}, where: 'uid = ?', whereArgs: [uid]);
  }
}
