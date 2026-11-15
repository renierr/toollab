import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

/// Post ids already reported to X as seen, kept for [retention] and looked
/// up per loaded page, so memory holds only the ids of loaded posts.
class XReadDb {
  static const String _table = 'read_posts';
  static const Duration retention = Duration(days: 30);

  /// Stays under SQLite's bound-variable limit.
  static const int _chunk = 500;

  XReadDb._();
  static final XReadDb instance = XReadDb._();

  Future<ToolDatabase>? _db;

  Future<ToolDatabase> _getDb() => _db ??= _open();

  Future<ToolDatabase> _open() async {
    final db = await DatabaseService.instance.getToolDatabase(
      XFeedTool.config.id,
    );
    try {
      await db.migrate(
        currentVersion: 1,
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
        },
      );
    } catch (e) {
      errorLog('[XReadDb] Migration failed: $e');
    }
    return db;
  }

  /// The subset of [ids] that was read.
  Future<Set<String>> readAmong(Iterable<String> ids) async {
    final all = ids.toSet().toList();
    if (all.isEmpty) return {};
    final db = await _getDb();
    final found = <String>{};
    for (var i = 0; i < all.length; i += _chunk) {
      final part = all.sublist(i, (i + _chunk).clamp(0, all.length));
      final rows = await db.query(
        _table,
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

  /// Deletes ids read before [retention] and returns how many.
  Future<int> prune() async {
    final db = await _getDb();
    final cutoff = DateTime.now().subtract(retention).millisecondsSinceEpoch;
    return db.delete(_table, where: 'read_at < ?', whereArgs: [cutoff]);
  }

  Future<void> clear() async {
    final db = await _getDb();
    await db.delete(_table);
  }
}
