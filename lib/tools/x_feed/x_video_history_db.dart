import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'models/x_watched_video.dart';
import 'x_read_db.dart';

/// Watched videos, newest first, capped at [maxEntries] and [retention] so
/// the table and the history tab stay small.
class XVideoHistoryDb {
  static const String _table = XReadDb.watchedVideosTable;
  static const int maxEntries = 1000;
  static const Duration retention = Duration(days: 400);

  XVideoHistoryDb._();
  static final XVideoHistoryDb instance = XVideoHistoryDb._();

  Future<List<XWatchedVideo>> entries() async {
    final db = await XReadDb.instance.database;
    final rows = await db.query(
      _table,
      orderBy: 'last_watched_at DESC',
      limit: maxEntries,
    );
    return rows.map(XWatchedVideo.fromMap).toList();
  }

  /// Adds [played] to [video]'s entry, creating it on the first view;
  /// [newPlay] counts one more play.
  Future<void> record(
    XWatchedVideo video, {
    required Duration duration,
    required Duration played,
    required bool newPlay,
  }) async {
    final db = await XReadDb.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      const key = 'post_id = ? AND media_index = ?';
      final args = [video.postId, video.mediaIndex];
      final existing = await txn.query(
        _table,
        columns: ['watched_ms', 'play_count'],
        where: key,
        whereArgs: args,
      );
      final row = existing.firstOrNull;
      if (row == null) {
        await txn.insert(_table, {
          ...video.toMap(),
          'duration_ms': duration.inMilliseconds,
          'watched_ms': played.inMilliseconds,
          'play_count': 1,
          'first_watched_at': now,
          'last_watched_at': now,
        });
        return;
      }
      await txn.update(
        _table,
        {
          'watched_ms': (row['watched_ms']! as int) + played.inMilliseconds,
          'play_count': (row['play_count']! as int) + (newPlay ? 1 : 0),
          'duration_ms': duration.inMilliseconds,
          'last_watched_at': now,
        },
        where: key,
        whereArgs: args,
      );
    });
  }

  Future<void> remove(XWatchedVideo entry) async {
    final db = await XReadDb.instance.database;
    await db.delete(
      _table,
      where: 'post_id = ? AND media_index = ?',
      whereArgs: [entry.postId, entry.mediaIndex],
    );
  }

  Future<void> restore(XWatchedVideo entry) async {
    final db = await XReadDb.instance.database;
    await db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes entries last watched more than [age] ago, or all when null;
  /// returns how many.
  Future<int> clearOlderThan(Duration? age) async {
    final db = await XReadDb.instance.database;
    if (age == null) return db.delete(_table);
    final cutoff = DateTime.now().subtract(age).millisecondsSinceEpoch;
    return db.delete(_table, where: 'last_watched_at < ?', whereArgs: [cutoff]);
  }

  /// Drops entries past [retention] and beyond [maxEntries]; returns how many.
  Future<int> prune() async {
    final db = await XReadDb.instance.database;
    final cutoff = DateTime.now().subtract(retention).millisecondsSinceEpoch;
    var removed = await db.delete(
      _table,
      where: 'last_watched_at < ?',
      whereArgs: [cutoff],
    );
    final oldestKept = await db.query(
      _table,
      columns: ['last_watched_at'],
      orderBy: 'last_watched_at DESC',
      limit: 1,
      offset: maxEntries - 1,
    );
    final floor = oldestKept.firstOrNull?['last_watched_at'] as int?;
    if (floor != null) {
      removed += await db.delete(
        _table,
        where: 'last_watched_at < ?',
        whereArgs: [floor],
      );
    }
    return removed;
  }
}
