import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/trimz_saved_series.dart';

class TrimzDbHelper {
  static const String tableName = 'series';

  TrimzDbHelper._();
  static final TrimzDbHelper instance = TrimzDbHelper._();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      TrimzTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                id TEXT PRIMARY KEY,
                slug TEXT NOT NULL,
                title TEXT NOT NULL,
                poster_url TEXT,
                episode_count INTEGER NOT NULL DEFAULT 0,
                episode_index INTEGER NOT NULL DEFAULT 0,
                position_ms INTEGER NOT NULL DEFAULT 0,
                duration_ms INTEGER NOT NULL DEFAULT 0,
                watched_at INTEGER,
                saved_at INTEGER
              )
            ''');
          }
        },
      );
    } catch (e) {
      errorLog('[TrimzDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  Future<List<TrimzSavedSeries>> all() async {
    final db = await _getDb();
    final rows = await db.query(tableName);
    return rows.map(TrimzSavedSeries.fromMap).toList();
  }

  Future<void> save(TrimzSavedSeries series) async {
    final db = await _getDb();
    await db.insert(
      tableName,
      series.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(tableName, where: 'saved_at IS NULL');
      await txn.update(tableName, {
        'episode_index': 0,
        'position_ms': 0,
        'duration_ms': 0,
        'watched_at': null,
      });
    });
  }

  Future<void> clearList() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(tableName, where: 'watched_at IS NULL');
      await txn.update(tableName, {'saved_at': null});
    });
  }
}
