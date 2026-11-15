import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'video_history_entry.dart';

class VideoHistoryDbHelper {
  static const String tableName = 'history';

  VideoHistoryDbHelper._();
  static final VideoHistoryDbHelper instance = VideoHistoryDbHelper._();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      VideoPlayerTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                source TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                position_ms INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                played_at INTEGER NOT NULL
              )
            ''');
          }
        },
      );
    } catch (e) {
      errorLog('[VideoHistoryDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  Future<List<VideoHistoryEntry>> recent() async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      orderBy: 'played_at DESC, rowid DESC',
    );
    return rows.map(VideoHistoryEntry.fromMap).toList();
  }

  Future<VideoHistoryEntry?> find(String source) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'source = ?',
      whereArgs: [source],
      limit: 1,
    );
    return rows.isEmpty ? null : VideoHistoryEntry.fromMap(rows.first);
  }

  Future<void> save(VideoHistoryEntry entry) async {
    final db = await _getDb();
    await db.insert(
      tableName,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String source) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'source = ?', whereArgs: [source]);
  }
}
