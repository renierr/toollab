import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tool_lab/services/database_service.dart';

class NotesDbHelper {
  static const String tableName = 'notes';
  static const String tagTableName = 'note_tags';

  NotesDbHelper._privateConstructor();
  static final NotesDbHelper instance = NotesDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase('notes');
    try {
      await _cachedDb!.migrate(
        currentVersion: 2,
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
          if (oldVersion < 2) {
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS ${txn.nameTable(tagTableName)} (
                note_id INTEGER NOT NULL,
                tag TEXT NOT NULL COLLATE NOCASE,
                PRIMARY KEY (note_id, tag)
              )
            ''');
          }
        },
      );
    } catch (e) {
      debugPrint('[NotesDbHelper] Migration failed, using fallback: $e');
    }
    return _cachedDb!;
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

  /// Gets active notes enriched with their tags.
  Future<List<Map<String, dynamic>>> getActiveNotesWithTags({
    String query = '',
  }) async {
    final rawNotes = await getActiveNotes(query: query);
    if (rawNotes.isEmpty) return rawNotes;
    final notes = rawNotes.map((m) => Map<String, dynamic>.from(m)).toList();
    try {
      final noteIds = notes.map((n) => n['id'] as int).toList();
      final tagsMap = await getTagsForNotes(noteIds);
      for (final note in notes) {
        note['tags'] = tagsMap[note['id'] as int] ?? <String>[];
      }
    } catch (e) {
      debugPrint('[NotesDbHelper] Failed to load tags: $e');
    }
    return notes;
  }

  /// Get all sync records (including deleted ones).
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
    if (rows.isEmpty) return null;
    final note = Map<String, dynamic>.from(rows.first);
    note['tags'] = await getTagsForNote(note['id'] as int);
    return note;
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
    if (rows.isEmpty) return null;
    final note = Map<String, dynamic>.from(rows.first);
    note['tags'] = await getTagsForNote(note['id'] as int);
    return note;
  }

  /// Save or update a note.
  Future<int> saveNote(
    String content, {
    int? id,
    String? shortId,
    List<String>? tags,
  }) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (id != null) {
      final note = await getNoteById(id);
      final noteShortId =
          note?['short_id'] as String? ?? shortId ?? generateShortId();
      final existingUpdatedAt = note?['updated_at'] as int? ?? 0;
      final updateUpdatedAt = max(now, existingUpdatedAt + 1);

      await db.update(
        tableName,
        {
          'content': content,
          'updated_at': updateUpdatedAt,
          'short_id': noteShortId,
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (tags != null) {
        await setTagsForNote(id, tags);
      }
      return id;
    } else {
      final noteShortId = shortId ?? generateShortId();
      final newId = await db.insert(tableName, {
        'short_id': noteShortId,
        'content': content,
        'created_at': now,
        'updated_at': now,
        'deleted': 0,
        'synced': 0,
      });

      if (tags != null && tags.isNotEmpty) {
        await setTagsForNote(newId, tags);
      }
      return newId;
    }
  }

  /// Soft delete note (flagged for sync deletion).
  Future<void> softDeleteNote(int id) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    final note = await getNoteById(id);
    final existingUpdatedAt = note?['updated_at'] as int? ?? 0;
    final deleteUpdatedAt = max(now, existingUpdatedAt + 1);

    await db.update(
      tableName,
      {'deleted': 1, 'updated_at': deleteUpdatedAt, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete note (called during sync finalize).
  Future<void> hardDeleteNote(String shortId) async {
    final db = await _getDb();
    final existing = await getNoteByShortId(shortId);
    if (existing != null) {
      final noteId = existing['id'] as int;
      await db.delete(tagTableName, where: 'note_id = ?', whereArgs: [noteId]);
    }
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
    List<String>? tags,
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
      if (tags != null) {
        await setTagsForNote(existing['id'] as int, tags);
      }
    } else {
      final newId = await db.insert(tableName, {
        'short_id': shortId,
        'content': content,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted': 0,
        'synced': 1,
      });
      if (tags != null && tags.isNotEmpty) {
        await setTagsForNote(newId, tags);
      }
    }
  }

  // ---- Tag CRUD ----

  /// Get tags for a single note.
  Future<List<String>> getTagsForNote(int noteId) async {
    final db = await _getDb();
    final rows = await db.query(
      tagTableName,
      columns: ['tag'],
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
    return rows.map((r) => r['tag'] as String).toList();
  }

  /// Get tags for multiple notes. Returns a map of note_id → tags.
  Future<Map<int, List<String>>> getTagsForNotes(List<int> noteIds) async {
    if (noteIds.isEmpty) return {};
    final db = await _getDb();
    final placeholders = noteIds.map((_) => '?').join(',');
    final rows = await db.query(
      tagTableName,
      where: 'note_id IN ($placeholders)',
      whereArgs: noteIds,
    );
    final result = <int, List<String>>{};
    for (final noteId in noteIds) {
      result[noteId] = [];
    }
    for (final row in rows) {
      final noteId = row['note_id'] as int;
      final tag = row['tag'] as String;
      result.putIfAbsent(noteId, () => []).add(tag);
    }
    return result;
  }

  /// Replace all tags for a note.
  Future<void> setTagsForNote(int noteId, List<String> tags) async {
    final db = await _getDb();
    final normalized = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    await db.delete(tagTableName, where: 'note_id = ?', whereArgs: [noteId]);

    for (final tag in normalized) {
      await db.insert(tagTableName, {'note_id': noteId, 'tag': tag});
    }
  }

  /// Get all distinct tags from non-deleted notes.
  Future<List<String>> getAllTags() async {
    final db = await _getDb();
    final rows = await db.rawQuery('''
      SELECT DISTINCT t.tag
      FROM ${db.nameTable(tagTableName)} t
      INNER JOIN ${db.nameTable(tableName)} n ON n.id = t.note_id
      WHERE n.deleted = 0
      ORDER BY t.tag ASC
    ''');
    return rows.map((r) => r['tag'] as String).toList();
  }
}
