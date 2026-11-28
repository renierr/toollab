import 'dart:async';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/trimz_saved_series.dart';
import 'models/trimz_sync_record.dart';

/// Rows are soft-deleted (`deleted = 1`) so the deletion reaches other devices
/// through sync; `updated_at` decides which device's row wins.
class TrimzDbHelper {
  static const String tableName = 'series';

  TrimzDbHelper._();
  static final TrimzDbHelper instance = TrimzDbHelper._();

  ToolDatabase? _cachedDb;
  final StreamController<void> _remoteChanges =
      StreamController<void>.broadcast();

  /// Fires when sync wrote or removed a row.
  Stream<void> get remoteChanges => _remoteChanges.stream;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      TrimzTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 2,
        onMigrate: (txn, oldVersion, newVersion) async {
          final table = txn.nameTable(tableName);
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE $table (
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
          if (oldVersion < 2) {
            await txn.execute(
              'ALTER TABLE $table ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
            );
            await txn.execute(
              'ALTER TABLE $table ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
            );
            await txn.execute(
              'UPDATE $table SET updated_at = '
              'MAX(COALESCE(watched_at, 0), COALESCE(saved_at, 0))',
            );
          }
        },
      );
    } catch (e) {
      errorLog('[TrimzDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<List<TrimzSavedSeries>> all() async {
    final db = await _getDb();
    final rows = await db.query(tableName, where: 'deleted = 0');
    return rows.map(TrimzSavedSeries.fromMap).toList();
  }

  Future<void> save(TrimzSavedSeries series) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      final rows = await txn.query(
        tableName,
        columns: ['updated_at'],
        where: 'id = ?',
        whereArgs: [series.id],
      );
      final previous = rows.isEmpty ? 0 : rows.first['updated_at'] as int;
      final now = _now;
      await txn.insert(tableName, {
        ...series.toMap(),
        'updated_at': now > previous ? now : previous + 1,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> delete(String id) async {
    final db = await _getDb();
    await db.rawUpdate(
      'UPDATE ${db.nameTable(tableName)} SET deleted = 1, '
      'updated_at = MAX(updated_at + 1, ?) WHERE id = ? AND deleted = 0',
      [_now, id],
    );
  }

  Future<void> clearHistory() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      final table = txn.nameTable(tableName);
      final now = _now;
      await txn.rawUpdate(
        'UPDATE $table SET deleted = 1, updated_at = MAX(updated_at + 1, ?) '
        'WHERE deleted = 0 AND saved_at IS NULL',
        [now],
      );
      await txn.rawUpdate(
        'UPDATE $table SET episode_index = 0, position_ms = 0, '
        'duration_ms = 0, watched_at = NULL, '
        'updated_at = MAX(updated_at + 1, ?) '
        'WHERE deleted = 0 AND watched_at IS NOT NULL',
        [now],
      );
    });
  }

  Future<void> clearList() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      final table = txn.nameTable(tableName);
      final now = _now;
      await txn.rawUpdate(
        'UPDATE $table SET deleted = 1, updated_at = MAX(updated_at + 1, ?) '
        'WHERE deleted = 0 AND watched_at IS NULL',
        [now],
      );
      await txn.rawUpdate(
        'UPDATE $table SET saved_at = NULL, '
        'updated_at = MAX(updated_at + 1, ?) '
        'WHERE deleted = 0 AND saved_at IS NOT NULL',
        [now],
      );
    });
  }

  Future<List<TrimzSyncRecord>> syncRecords() async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      columns: ['id', 'updated_at', 'deleted'],
    );
    return rows.map(TrimzSyncRecord.fromMap).toList();
  }

  Future<TrimzSavedSeries?> live(String id) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : TrimzSavedSeries.fromMap(rows.first);
  }

  /// Keeps the local row when it is as new as the pulled one or newer.
  Future<void> savePulled(TrimzSavedSeries series, int updatedAt) async {
    final db = await _getDb();
    final changed = await db.transaction((txn) async {
      final rows = await txn.query(
        tableName,
        columns: ['updated_at'],
        where: 'id = ?',
        whereArgs: [series.id],
      );
      if (rows.isNotEmpty && (rows.first['updated_at'] as int) >= updatedAt) {
        return false;
      }
      await txn.insert(tableName, {
        ...series.toMap(),
        'updated_at': updatedAt,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
    if (changed) _remoteChanges.add(null);
  }

  /// Drops the row unless it changed after sync observed it at [observed].
  Future<void> finalizeDeletion(String id, int observed) async {
    final db = await _getDb();
    final removed = await db.delete(
      tableName,
      where: 'id = ? AND updated_at <= ?',
      whereArgs: [id, observed],
    );
    if (removed > 0) _remoteChanges.add(null);
  }
}
