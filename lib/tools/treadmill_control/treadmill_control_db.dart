import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tool_lab/services/database_service.dart';
import 'config.dart';
import 'treadmill_session.dart';

class TreadmillControlDb {
  static const String tableName = 'workout_sessions';

  TreadmillControlDb._privateConstructor();
  static final TreadmillControlDb instance =
      TreadmillControlDb._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      TreadmillControlTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                uid TEXT NOT NULL UNIQUE,
                start_time INTEGER NOT NULL,
                end_time INTEGER,
                avg_speed REAL NOT NULL,
                max_speed REAL NOT NULL,
                distance REAL NOT NULL,
                calories INTEGER NOT NULL,
                steps INTEGER NOT NULL,
                avg_heart_rate REAL NOT NULL,
                max_heart_rate REAL NOT NULL,
                elapsed_time INTEGER NOT NULL,
                data_points TEXT NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0,
                deleted INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL,
                created_at INTEGER NOT NULL
              )
            ''');
          }
        },
      );
    } catch (e) {
      debugPrint('[TreadmillControlDb] Migration failed: $e');
    }
    return _cachedDb!;
  }

  String generateUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(32, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<List<TreadmillSession>> getActiveSessions() async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'deleted = 0',
      orderBy: 'start_time DESC',
    );
    return rows.map((r) => TreadmillSession.fromMap(r)).toList();
  }

  Future<TreadmillSession?> getSessionByUid(String uid) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TreadmillSession.fromMap(rows.first);
  }

  Future<int> saveSession(TreadmillSession session) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (session.id != null) {
      final existing = await getSessionByUid(session.uid);
      final existingUpdatedAt = existing?.updatedAt ?? 0;
      final updateUpdatedAt = max(now, existingUpdatedAt + 1);

      final updated = session.copyWith(
        updatedAt: updateUpdatedAt,
        synced: false,
      );

      await db.update(
        tableName,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [session.id],
      );
      return session.id!;
    } else {
      final uid = session.uid.isEmpty ? generateUid() : session.uid;
      final inserted = session.copyWith(
        uid: uid,
        createdAt: session.createdAt == 0 ? now : session.createdAt,
        updatedAt: session.updatedAt == 0 ? now : session.updatedAt,
        synced: false,
      );

      final newId = await db.insert(tableName, inserted.toMap());
      return newId;
    }
  }

  Future<void> softDeleteSession(int id) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      tableName,
      {'deleted': 1, 'updated_at': now, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hardDeleteSession(String uid) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'uid = ?', whereArgs: [uid]);
  }

  Future<void> markSynced(String uid) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {'synced': 1},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  /// Get all sync records (including deleted ones).
  Future<List<Map<String, dynamic>>> getSyncRecords() async {
    final db = await _getDb();
    return await db.query(tableName, columns: ['uid', 'updated_at', 'deleted']);
  }

  /// Sync pull upsert handler.
  Future<void> savePulledSession(TreadmillSession session) async {
    final db = await _getDb();
    if (session.deleted) {
      await hardDeleteSession(session.uid);
      return;
    }

    final existing = await getSessionByUid(session.uid);
    final values = session.copyWith(synced: true).toMap()..remove('id');
    if (existing != null) {
      await db.update(
        tableName,
        values,
        where: 'uid = ?',
        whereArgs: [session.uid],
      );
    } else {
      await db.insert(tableName, values);
    }
  }

  Future<int> importSessions(List<TreadmillSession> sessions) async {
    final db = await _getDb();
    return db.transaction((txn) async {
      var importedCount = 0;
      for (final session in sessions) {
        if (session.uid.isEmpty) continue;
        final existing = await txn.query(
          tableName,
          columns: ['id'],
          where: 'uid = ?',
          whereArgs: [session.uid],
          limit: 1,
        );
        if (existing.isEmpty) {
          final values = session.toMap()..remove('id');
          await txn.insert(tableName, values);
          importedCount++;
        }
      }
      return importedCount;
    });
  }
}
