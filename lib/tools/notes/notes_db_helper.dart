import 'dart:math';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/notes/config.dart';

class NotesDbHelper {
  static const String tableName = 'notes';
  static const String tagTableName = 'note_tags';

  NotesDbHelper._privateConstructor();
  static final NotesDbHelper instance = NotesDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      NotesTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 3,
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
          if (oldVersion < 3) {
            // Threading key is short_id, not the local row id: a child pulled
            // before its parent still resolves once the parent arrives.
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(tableName)} ADD COLUMN parent_short_id TEXT',
            );
            await txn.execute(
              'CREATE INDEX IF NOT EXISTS idx_${txn.nameTable(tableName)}_parent '
              'ON ${txn.nameTable(tableName)}(parent_short_id)',
            );
          }
        },
      );
    } catch (e) {
      errorLog('[NotesDbHelper] Migration failed, using fallback: $e');
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
      errorLog('[NotesDbHelper] Failed to load tags: $e');
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
    String? parentShortId,
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
        'parent_short_id': parentShortId,
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
      // Never leave dangling children behind: lift them to the removed parent.
      await db.update(
        tableName,
        {'parent_short_id': existing['parent_short_id'], 'synced': 0},
        where: 'parent_short_id = ?',
        whereArgs: [shortId],
      );
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
    String? parentShortId,
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
          'parent_short_id': parentShortId,
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
        'parent_short_id': parentShortId,
      });
      if (tags != null && tags.isNotEmpty) {
        await setTagsForNote(newId, tags);
      }
    }
  }

  // ---- Threading ----

  /// short_id → parent_short_id for every active note.
  Future<Map<String, String?>> getParentLinks() async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      columns: ['short_id', 'parent_short_id'],
      where: 'deleted = 0',
    );
    return {
      for (final r in rows)
        r['short_id'] as String: r['parent_short_id'] as String?,
    };
  }

  /// Direct children of a note, oldest first.
  Future<List<Map<String, dynamic>>> getChildren(String parentShortId) async {
    final db = await _getDb();
    return await db.query(
      tableName,
      where: 'deleted = 0 AND parent_short_id = ?',
      whereArgs: [parentShortId],
      orderBy: 'created_at ASC',
    );
  }

  /// All descendant short IDs of [shortId], depth first.
  Future<List<String>> getDescendantShortIds(String shortId) async {
    final links = await getParentLinks();
    final childrenOf = <String, List<String>>{};
    links.forEach((child, parent) {
      if (parent != null) childrenOf.putIfAbsent(parent, () => []).add(child);
    });
    final result = <String>[];
    final stack = [...?childrenOf[shortId]];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (result.contains(current)) continue;
      result.add(current);
      stack.addAll(childrenOf[current] ?? const []);
    }
    return result;
  }

  /// Re-parents a note. Passing null detaches it into a root note.
  /// Refuses moves that would build a cycle.
  Future<bool> setParent(int id, String? parentShortId) async {
    final note = await getNoteById(id);
    if (note == null) return false;
    final shortId = note['short_id'] as String;
    if (parentShortId == shortId) return false;

    if (parentShortId != null) {
      final links = await getParentLinks();
      if (!links.containsKey(parentShortId)) return false;
      String? cursor = parentShortId;
      final seen = <String>{};
      while (cursor != null && seen.add(cursor)) {
        if (cursor == shortId) return false;
        cursor = links[cursor];
      }
    }

    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedAt = max(now, (note['updated_at'] as int? ?? 0) + 1);
    await db.update(
      tableName,
      {'parent_short_id': parentShortId, 'updated_at': updatedAt, 'synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    return true;
  }

  /// Soft deletes a note together with its whole subtree.
  /// Returns the number of deleted notes.
  Future<int> softDeleteSubtree(int id) async {
    final note = await getNoteById(id);
    if (note == null) return 0;
    final descendants = await getDescendantShortIds(note['short_id'] as String);
    await softDeleteNote(id);
    for (final shortId in descendants) {
      final child = await getNoteByShortId(shortId);
      if (child != null) await softDeleteNote(child['id'] as int);
    }
    return descendants.length + 1;
  }

  /// Soft deletes a note and lifts its direct children to its own parent.
  Future<void> softDeleteAndPromoteChildren(int id) async {
    final note = await getNoteById(id);
    if (note == null) return;
    final db = await _getDb();
    await db.update(
      tableName,
      {'parent_short_id': note['parent_short_id'], 'synced': 0},
      where: 'parent_short_id = ?',
      whereArgs: [note['short_id'] as String],
    );
    await softDeleteNote(id);
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
