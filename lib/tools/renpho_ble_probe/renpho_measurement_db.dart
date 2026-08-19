import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'renpho_measurement.dart';

class RenphoMeasurementDb {
  RenphoMeasurementDb._();
  static final instance = RenphoMeasurementDb._();
  static const _table = 'measurements';
  ToolDatabase? _db;

  Future<ToolDatabase> _database() async {
    _db ??= await DatabaseService.instance.getToolDatabase(
      RenphoBleProbeTool.config.id,
    );
    await _db!.migrate(
      currentVersion: 1,
      onMigrate: (txn, _, _) async {
        await txn.execute('''CREATE TABLE ${txn.nameTable(_table)} (
        id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT UNIQUE NOT NULL,
        measured_at INTEGER NOT NULL, weight_kg REAL NOT NULL, bmi REAL NOT NULL,
        body_fat_percent REAL NOT NULL, muscle_percent REAL NOT NULL,
        visceral_fat INTEGER NOT NULL, impedance_json TEXT NOT NULL,
        packet_hex TEXT NOT NULL, health_connect_published_at INTEGER NOT NULL DEFAULT 0
      )''');
      },
    );
    return _db!;
  }

  Future<void> save(RenphoMeasurement measurement) async {
    final db = await _database();
    await db.insert(
      _table,
      measurement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RenphoMeasurement>> recent() async {
    final db = await _database();
    final rows = await db.query(
      _table,
      orderBy: 'measured_at DESC',
      limit: 100,
    );
    return rows.map(RenphoMeasurement.fromMap).toList();
  }

  Future<List<RenphoMeasurement>> pendingHealthConnect() async {
    final db = await _database();
    final rows = await db.query(
      _table,
      where: 'health_connect_published_at = 0',
      orderBy: 'measured_at ASC',
    );
    return rows.map(RenphoMeasurement.fromMap).toList();
  }

  Future<void> markPublished(RenphoMeasurement measurement) async {
    final db = await _database();
    await db.update(
      _table,
      {'health_connect_published_at': DateTime.now().millisecondsSinceEpoch},
      where: 'uid = ?',
      whereArgs: [measurement.uid],
    );
  }

  String newUid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
}
