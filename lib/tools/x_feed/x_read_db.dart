import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

/// Post ids already reported to X as seen, kept for [retention], and posts
/// boosted, kept for good. Both are looked up per loaded page, so memory
/// holds only the ids of loaded posts. Also owns the schema of
/// [watchedVideosTable], which [XVideoHistoryDb] reads and writes.
class XReadDb {
  static const String _table = 'read_posts';
  static const String _boostedTable = 'boosted_posts';
  static const String watchedVideosTable = 'watched_videos';
  static const Duration retention = Duration(days: 30);

  /// Stays under SQLite's bound-variable limit.
  static const int _chunk = 500;

  XReadDb._();
  static final XReadDb instance = XReadDb._();

  Future<ToolDatabase>? _db;

  Future<ToolDatabase> get database => _db ??= _open();

  Future<ToolDatabase> _getDb() => database;

  Future<ToolDatabase> _open() async {
    final db = await DatabaseService.instance.getToolDatabase(
      XFeedTool.config.id,
    );
    try {
      await db.migrate(
        currentVersion: 3,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_table)} (
                post_id TEXT PRIMARY KEY,
                read_at INTEGER NOT NULL
              ) WITHOUT ROWID
            ''');
            await txn.execute(
              'CREATE INDEX ${txn.nameTable('${_table}_read_at')} '
              'ON ${txn.nameTable(_table)} (read_at)',
            );
          }
          if (oldVersion < 2) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_boostedTable)} (
                post_id TEXT PRIMARY KEY,
                boosted_at INTEGER NOT NULL
              ) WITHOUT ROWID
            ''');
          }
          if (oldVersion < 3) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(watchedVideosTable)} (
                post_id TEXT NOT NULL,
                media_index INTEGER NOT NULL,
                author_screen_name TEXT NOT NULL,
                author_name TEXT NOT NULL,
                avatar_url TEXT,
                text TEXT NOT NULL,
                video_url TEXT NOT NULL,
                preview_url TEXT NOT NULL,
                is_gif INTEGER NOT NULL,
                duration_ms INTEGER NOT NULL,
                watched_ms INTEGER NOT NULL,
                play_count INTEGER NOT NULL,
                first_watched_at INTEGER NOT NULL,
                last_watched_at INTEGER NOT NULL,
                PRIMARY KEY (post_id, media_index)
              ) WITHOUT ROWID
            ''');
            await txn.execute(
              'CREATE INDEX ${txn.nameTable('${watchedVideosTable}_last')} '
              'ON ${txn.nameTable(watchedVideosTable)} (last_watched_at)',
            );
          }
        },
      );
    } catch (e) {
      errorLog('[XReadDb] Migration failed: $e');
    }
    return db;
  }

  /// The subset of [ids] that was read.
  Future<Set<String>> readAmong(Iterable<String> ids) => _among(_table, ids);

  /// The subset of [ids] that was boosted.
  Future<Set<String>> boostedAmong(Iterable<String> ids) =>
      _among(_boostedTable, ids);

  Future<Set<String>> _among(String table, Iterable<String> ids) async {
    final all = ids.toSet().toList();
    if (all.isEmpty) return {};
    final db = await _getDb();
    final found = <String>{};
    for (var i = 0; i < all.length; i += _chunk) {
      final part = all.sublist(i, (i + _chunk).clamp(0, all.length));
      final rows = await db.query(
        table,
        columns: ['post_id'],
        where: 'post_id IN (${List.filled(part.length, '?').join(',')})',
        whereArgs: part,
      );
      found.addAll(rows.map((r) => r['post_id']! as String));
    }
    return found;
  }

  Future<void> markRead(Iterable<String> ids) async {
    final all = ids.toSet();
    if (all.isEmpty) return;
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final id in all) {
      batch.insert(_table, {
        'post_id': id,
        'read_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> markBoosted(String id) async {
    final db = await _getDb();
    await db.insert(_boostedTable, {
      'post_id': id,
      'boosted_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deletes ids read before [retention] and returns how many.
  Future<int> prune() async {
    final db = await _getDb();
    final cutoff = DateTime.now().subtract(retention).millisecondsSinceEpoch;
    return db.delete(_table, where: 'read_at < ?', whereArgs: [cutoff]);
  }

  Future<void> clear() async {
    final db = await _getDb();
    await db.delete(_table);
    await db.delete(_boostedTable);
    await db.delete(watchedVideosTable);
  }
}
