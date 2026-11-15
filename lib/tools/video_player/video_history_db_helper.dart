import 'dart:typed_data';

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
        currentVersion: 2,
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
          if (oldVersion < 2) {
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(tableName)} ADD COLUMN thumbnail BLOB',
            );
          }
        },
      );
    } catch (e) {
      errorLog('[VideoHistoryDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  static const String _newestFirst = 'played_at DESC, rowid DESC';

  Future<List<VideoHistoryEntry>> recent() async {
    final db = await _getDb();
    final rows = await db.query(tableName, orderBy: _newestFirst);
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

  /// True when the source was not in the list yet.
  Future<bool> save(VideoHistoryEntry entry) async {
    final db = await _getDb();
    final updated = await db.update(
      tableName,
      entry.toMap(),
      where: 'source = ?',
      whereArgs: [entry.source],
    );
    if (updated > 0) return false;
    await db.insert(tableName, entry.toMap());
    return true;
  }

  /// Deletes all but the newest [keep] entries and returns their sources.
  Future<List<String>> prune(int keep) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      columns: ['source'],
      orderBy: _newestFirst,
      limit: -1,
      offset: keep,
    );
    final sources = [for (final row in rows) row['source']! as String];
    if (sources.isNotEmpty) {
      await db.delete(
        tableName,
        where: 'source IN (${List.filled(sources.length, '?').join(',')})',
        whereArgs: sources,
      );
    }
    return sources;
  }

  Future<void> saveThumbnail(String source, Uint8List jpeg) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {'thumbnail': jpeg},
      where: 'source = ?',
      whereArgs: [source],
    );
  }

  Future<void> delete(String source) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'source = ?', whereArgs: [source]);
  }

  /// Returns the deleted sources.
  Future<List<String>> clear() => prune(0);
}
