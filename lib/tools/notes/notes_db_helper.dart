import 'dart:math';
import 'package:tool_lab/services/database_service.dart';

class NotesDbHelper {
  static const String tableName = 'notes';

  NotesDbHelper._privateConstructor();
  static final NotesDbHelper instance = NotesDbHelper._privateConstructor();

  bool _isInitialized = false;

  Future<ToolDatabase> _getDb() async {
    final db = await DatabaseService.instance.getToolDatabase('notes');
    if (!_isInitialized) {
      await db.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                short_id TEXT NOT NULL UNIQUE,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');
          }
        },
      );
      _isInitialized = true;
    }
    return db;
  }

  String generateShortId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Get all active (non-deleted) notes sorted by updated_at descending.
  Future<List<Map<String, dynamic>>> getActiveNotes({String query = ''}) async {
    final db = await _getDb();
    if (query.trim().isEmpty) {
      return await db.query(
        tableName,
        where: 'deleted = 0',
        orderBy: 'updated_at DESC',
      );
    } else {
      return await db.query(
        tableName,
        where: 'deleted = 0 AND content LIKE ?',
        whereArgs: ['%${query.trim()}%'],
        orderBy: 'updated_at DESC',
      );
    }
  }

  /// Get all notes (including deleted and unsynced ones) for SyncDelegate metadata.
  Future<List<Map<String, dynamic>>> getSyncRecords() async {
    final db = await _getDb();
    return await db.query(
      tableName,
      columns: ['short_id', 'updated_at', 'deleted'],
    );
  }

  /// Get note content and details by short ID.
  Future<Map<String, dynamic>?> getNoteByShortId(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Get note details by integer ID.
  Future<Map<String, dynamic>?> getNoteById(int id) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Save or update a note.
  Future<int> saveNote(String content, {int? id, String? shortId}) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (id != null) {
      // Update existing
      final note = await getNoteById(id);
      final noteShortId =
          note?['short_id'] as String? ?? shortId ?? generateShortId();
      await db.update(
        tableName,
        {
          'content': content,
          'updated_at': now,
          'short_id': noteShortId,
          'synced': 0, // Mark as unsynced
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    } else {
      // Insert new
      final noteShortId = shortId ?? generateShortId();
      return await db.insert(tableName, {
        'short_id': noteShortId,
        'content': content,
        'created_at': now,
        'updated_at': now,
        'deleted': 0,
        'synced': 0,
      });
    }
  }

  /// Soft delete note (flagged for sync deletion).
  Future<void> softDeleteNote(int id) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      tableName,
      {
        'deleted': 1,
        'updated_at': now,
        'synced': 0, // Needs syncing to push deletion
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete note (called during sync finalize or if local unsynced deletion is done).
  Future<void> hardDeleteNote(String shortId) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'short_id = ?', whereArgs: [shortId]);
  }

  /// Mark a note as successfully synced.
  Future<void> markSynced(String shortId) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {'synced': 1},
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  /// Sync pull upsert handler.
  Future<void> savePulledNote({
    required String shortId,
    required String content,
    required int createdAt,
    required int updatedAt,
    required bool deleted,
  }) async {
    final db = await _getDb();
    if (deleted) {
      await hardDeleteNote(shortId);
      return;
    }

    final existing = await getNoteByShortId(shortId);
    if (existing != null) {
      await db.update(
        tableName,
        {
          'content': content,
          'created_at': createdAt,
          'updated_at': updatedAt,
          'deleted': 0,
          'synced': 1,
        },
        where: 'short_id = ?',
        whereArgs: [shortId],
      );
    } else {
      await db.insert(tableName, {
        'short_id': shortId,
        'content': content,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted': 0,
        'synced': 1,
      });
    }
  }
}
