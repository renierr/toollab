import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/id_helper.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/todo/config.dart';
import 'package:tool_lab/tools/todo/models/todo_attachment.dart';
import 'package:tool_lab/tools/todo/models/todo_folder.dart';
import 'package:tool_lab/tools/todo/models/todo_list.dart';
import 'package:tool_lab/tools/todo/models/todo_task.dart';
import 'package:tool_lab/tools/todo/models/todo_trash_item.dart';

enum TodoRecordKind { folder, list, task, attachment }

class TodoSyncRecord {
  final TodoRecordKind kind;
  final String shortId;
  final int updatedAt;
  final bool deleted;

  const TodoSyncRecord({
    required this.kind,
    required this.shortId,
    required this.updatedAt,
    required this.deleted,
  });
}

class TodoDbHelper {
  static const String foldersTable = 'todo_folders';
  static const String listsTable = 'todo_lists';
  static const String tasksTable = 'todo_tasks';
  static const String attachmentsTable = 'todo_attachments';

  /// Local only, never synced: snapshots of deleted tasks for restoring.
  static const String trashTable = 'todo_trash';

  static const Map<TodoRecordKind, String> _tables = {
    TodoRecordKind.folder: foldersTable,
    TodoRecordKind.list: listsTable,
    TodoRecordKind.task: tasksTable,
    TodoRecordKind.attachment: attachmentsTable,
  };

  TodoDbHelper._();
  static final TodoDbHelper instance = TodoDbHelper._();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    final db = await DatabaseService.instance.getToolDatabase(
      TodoTool.config.id,
    );
    await db.migrate(
      currentVersion: 2,
      onMigrate: (txn, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          const sync = '''
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0,
            synced INTEGER NOT NULL DEFAULT 0''';
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(foldersTable)} (
              short_id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              sort_order REAL NOT NULL DEFAULT 0,
              $sync
            )''');
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(listsTable)} (
              short_id TEXT PRIMARY KEY,
              folder_id TEXT,
              name TEXT NOT NULL,
              emoji TEXT NOT NULL DEFAULT '',
              color INTEGER NOT NULL,
              sort_order REAL NOT NULL DEFAULT 0,
              $sync
            )''');
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(tasksTable)} (
              short_id TEXT PRIMARY KEY,
              list_id TEXT NOT NULL,
              title TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              important INTEGER NOT NULL DEFAULT 0,
              my_day TEXT,
              due_at INTEGER,
              due_has_time INTEGER NOT NULL DEFAULT 0,
              recurrence TEXT,
              completed_at INTEGER,
              sort_order REAL NOT NULL DEFAULT 0,
              steps TEXT NOT NULL DEFAULT '[]',
              reminders TEXT NOT NULL DEFAULT '[]',
              tags TEXT NOT NULL DEFAULT '[]',
              $sync
            )''');
          await txn.execute(
            'CREATE INDEX idx_${txn.nameTable(tasksTable)}_list '
            'ON ${txn.nameTable(tasksTable)}(list_id)',
          );
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(attachmentsTable)} (
              short_id TEXT PRIMARY KEY,
              task_id TEXT NOT NULL,
              name TEXT NOT NULL,
              mime_type TEXT NOT NULL,
              size INTEGER NOT NULL,
              data BLOB,
              thumbnail BLOB,
              $sync
            )''');
          await txn.execute(
            'CREATE INDEX idx_${txn.nameTable(attachmentsTable)}_task '
            'ON ${txn.nameTable(attachmentsTable)}(task_id)',
          );
        }
        if (oldVersion < 2) {
          await txn.execute(
            'ALTER TABLE ${txn.nameTable(tasksTable)} ADD COLUMN start_at INTEGER',
          );
          await txn.execute('''
            CREATE TABLE ${txn.nameTable(trashTable)} (
              short_id TEXT PRIMARY KEY,
              deleted_at INTEGER NOT NULL,
              data TEXT NOT NULL
            )''');
        }
      },
    );
    return _cachedDb = db;
  }

  String generateShortId() => randomId(10);

  Future<List<TodoFolder>> getFolders() async {
    final db = await _getDb();
    final rows = await db.query(
      foldersTable,
      where: 'deleted = 0',
      orderBy: 'sort_order, created_at',
    );
    return rows.map(TodoFolder.fromMap).toList();
  }

  Future<List<TodoList>> getLists() async {
    final db = await _getDb();
    final rows = await db.query(
      listsTable,
      where: 'deleted = 0',
      orderBy: 'sort_order, created_at',
    );
    return rows.map(TodoList.fromMap).toList();
  }

  Future<List<TodoTask>> getTasks() async {
    final db = await _getDb();
    final rows = await db.query(
      tasksTable,
      where: 'deleted = 0',
      orderBy: 'sort_order, created_at',
    );
    return rows.map(TodoTask.fromMap).toList();
  }

  Future<TodoTask?> getTask(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      tasksTable,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : TodoTask.fromMap(rows.first);
  }

  Future<TodoFolder?> getFolder(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      foldersTable,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : TodoFolder.fromMap(rows.first);
  }

  Future<TodoList?> getList(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      listsTable,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : TodoList.fromMap(rows.first);
  }

  Future<List<TodoAttachment>> getAttachments() async {
    final db = await _getDb();
    final rows = await db.query(
      attachmentsTable,
      columns: [
        'short_id',
        'task_id',
        'name',
        'mime_type',
        'size',
        'thumbnail',
        'created_at',
        'updated_at',
      ],
      where: 'deleted = 0',
      orderBy: 'created_at',
    );
    return rows.map(TodoAttachment.fromMap).toList();
  }

  Future<Uint8List?> getAttachmentData(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      attachmentsTable,
      columns: ['data'],
      where: 'short_id = ? AND deleted = 0',
      whereArgs: [shortId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['data'] as Uint8List?;
  }

  Future<TodoAttachment?> getAttachment(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      attachmentsTable,
      columns: [
        'short_id',
        'task_id',
        'name',
        'mime_type',
        'size',
        'thumbnail',
        'created_at',
        'updated_at',
        'deleted',
      ],
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['deleted'] == 1) return null;
    return TodoAttachment.fromMap(rows.first);
  }

  Future<void> upsertFolder(TodoFolder folder, {bool synced = false}) =>
      _upsert(foldersTable, {...folder.toRow(), 'synced': synced ? 1 : 0});

  Future<void> upsertList(TodoList list, {bool synced = false}) =>
      _upsert(listsTable, {...list.toRow(), 'synced': synced ? 1 : 0});

  Future<void> upsertTask(TodoTask task, {bool synced = false}) =>
      _upsert(tasksTable, {...task.toRow(), 'synced': synced ? 1 : 0});

  Future<void> upsertTasks(List<TodoTask> tasks) async {
    if (tasks.isEmpty) return;
    final db = await _getDb();
    await db.transaction((txn) async {
      for (final task in tasks) {
        await txn.insert(tasksTable, {
          ...task.toRow(),
          'synced': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> insertAttachment({
    required String shortId,
    required String taskId,
    required String name,
    required String mimeType,
    required Uint8List data,
    Uint8List? thumbnail,
    required int createdAt,
    required int updatedAt,
    bool synced = false,
  }) => _upsert(attachmentsTable, {
    'short_id': shortId,
    'task_id': taskId,
    'name': name,
    'mime_type': mimeType,
    'size': data.length,
    'data': data,
    'thumbnail': thumbnail,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted': 0,
    'synced': synced ? 1 : 0,
  });

  Future<void> _upsert(String table, Map<String, Object?> row) async {
    final db = await _getDb();
    await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Tombstones the record so the deletion syncs.
  Future<void> softDelete(TodoRecordKind kind, String shortId) async {
    final db = await _getDb();
    final values = <String, Object?>{
      'deleted': 1,
      'synced': 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (kind == TodoRecordKind.attachment) {
      values['data'] = null;
      values['thumbnail'] = null;
    }
    await db.update(
      _tables[kind]!,
      values,
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<void> addToTrash(List<TodoTask> tasks, int deletedAt) async {
    if (tasks.isEmpty) return;
    final db = await _getDb();
    await db.transaction((txn) async {
      for (final task in tasks) {
        await txn.insert(
          trashTable,
          TodoTrashItem(task: task, deletedAt: deletedAt).toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<TodoTrashItem>> getTrash() async {
    final db = await _getDb();
    final rows = await db.query(trashTable, orderBy: 'deleted_at DESC');
    return [for (final row in rows) ?TodoTrashItem.fromMap(row)];
  }

  /// Removes the given entries, or all with [olderThan] / no arguments.
  Future<void> removeFromTrash({List<String>? ids, int? olderThan}) async {
    final db = await _getDb();
    if (ids != null) {
      if (ids.isEmpty) return;
      await db.delete(
        trashTable,
        where: 'short_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
    } else if (olderThan != null) {
      await db.delete(
        trashTable,
        where: 'deleted_at < ?',
        whereArgs: [olderThan],
      );
    } else {
      await db.delete(trashTable);
    }
  }

  /// Completed tasks done before [before], for the automatic cleanup.
  Future<List<TodoTask>> getCompletedBefore(int before) async {
    final db = await _getDb();
    final rows = await db.query(
      tasksTable,
      where: 'deleted = 0 AND completed_at IS NOT NULL AND completed_at < ?',
      whereArgs: [before],
    );
    return rows.map(TodoTask.fromMap).toList();
  }

  Future<void> markPulledDeleted(
    TodoRecordKind kind,
    String shortId,
    int updatedAt,
  ) async {
    final db = await _getDb();
    final values = <String, Object?>{
      'deleted': 1,
      'synced': 1,
      'updated_at': updatedAt,
    };
    if (kind == TodoRecordKind.attachment) {
      values['data'] = null;
      values['thumbnail'] = null;
    }
    await db.update(
      _tables[kind]!,
      values,
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<List<TodoSyncRecord>> getSyncRecords() async {
    final db = await _getDb();
    final records = <TodoSyncRecord>[];
    for (final entry in _tables.entries) {
      final rows = await db.query(
        entry.value,
        columns: ['short_id', 'updated_at', 'deleted'],
      );
      for (final row in rows) {
        records.add(
          TodoSyncRecord(
            kind: entry.key,
            shortId: row['short_id'] as String,
            updatedAt: row['updated_at'] as int? ?? 0,
            deleted: (row['deleted'] as int? ?? 0) == 1,
          ),
        );
      }
    }
    return records;
  }

  Future<int?> getUpdatedAt(TodoRecordKind kind, String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      _tables[kind]!,
      columns: ['updated_at'],
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['updated_at'] as int?;
  }

  Future<void> finalizeSync(
    TodoRecordKind kind,
    String shortId,
    bool wasDeleted,
  ) async {
    final db = await _getDb();
    if (wasDeleted) {
      await db.delete(
        _tables[kind]!,
        where: 'short_id = ? AND deleted = 1',
        whereArgs: [shortId],
      );
    } else {
      await db.update(
        _tables[kind]!,
        {'synced': 1},
        where: 'short_id = ?',
        whereArgs: [shortId],
      );
    }
  }
}
