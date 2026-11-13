import 'dart:typed_data';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'chat_models.dart';
import 'config.dart';

class ChatAiDbHelper {
  static const String sessionTable = 'chat_sessions';
  static const String messageTable = 'chat_messages';

  ChatAiDbHelper._privateConstructor();
  static final ChatAiDbHelper instance = ChatAiDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      ChatAiTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 4,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(sessionTable)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');

            await txn.execute('''
              CREATE TABLE ${txn.nameTable(messageTable)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (session_id) REFERENCES ${txn.nameTable(sessionTable)} (id) ON DELETE CASCADE
              )
            ''');
          }
          if (oldVersion < 2) {
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(messageTable)} ADD COLUMN image_data BLOB',
            );
          }
          if (oldVersion < 3) {
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(messageTable)} ADD COLUMN file_name TEXT',
            );
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(messageTable)} ADD COLUMN file_content TEXT',
            );
          }
          if (oldVersion < 4) {
            final sessions = txn.nameTable(sessionTable);
            await txn.execute('ALTER TABLE $sessions ADD COLUMN backend TEXT');
            await txn.execute(
              'ALTER TABLE $sessions ADD COLUMN remote_id TEXT',
            );
            await txn.execute(
              'ALTER TABLE $sessions ADD COLUMN remote_parent_id INTEGER',
            );
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(messageTable)} ADD COLUMN thinking TEXT',
            );
          }
        },
      );
    } catch (e) {
      errorLog('[ChatAiDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  /// Gets all chat sessions sorted by updated_at descending.
  Future<List<ChatSession>> getSessions() async {
    final db = await _getDb();
    final rows = await db.query(sessionTable, orderBy: 'updated_at DESC');
    return rows.map(ChatSession.fromMap).toList();
  }

  /// Creates a new chat session.
  Future<int> createSession(String title, {ChatBackend? backend}) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert(sessionTable, {
      'title': title,
      'backend': backend?.name,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Updates a session title.
  Future<void> updateSessionTitle(int sessionId, String title) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      sessionTable,
      {'title': title, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Remembers the remote conversation a session continues.
  Future<void> updateRemote(
    int sessionId, {
    required String remoteId,
    required int? parentId,
  }) async {
    final db = await _getDb();
    await db.update(
      sessionTable,
      {'remote_id': remoteId, 'remote_parent_id': parentId},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Mirrors the account's DeepSeek conversations: adds new ones, renames
  /// known ones and drops those deleted elsewhere. [complete] says the list
  /// is the whole history, so a missing conversation was deleted.
  Future<void> syncRemoteSessions(
    List<({String id, String title, int updatedAt})> remote, {
    required bool complete,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      final rows = await txn.query(
        sessionTable,
        columns: ['id', 'remote_id'],
        where: 'backend = ? AND remote_id IS NOT NULL',
        whereArgs: [ChatBackend.deepseek.name],
      );
      final local = {
        for (final row in rows) row['remote_id'] as String: row['id'] as int,
      };
      for (final session in remote) {
        final id = local.remove(session.id);
        final values = {
          'title': session.title,
          'updated_at': session.updatedAt,
        };
        if (id == null) {
          await txn.insert(sessionTable, {
            ...values,
            'backend': ChatBackend.deepseek.name,
            'remote_id': session.id,
            'created_at': session.updatedAt,
          });
        } else {
          await txn.update(
            sessionTable,
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      if (!complete) return;
      for (final id in local.values) {
        await txn.delete(
          messageTable,
          where: 'session_id = ?',
          whereArgs: [id],
        );
        await txn.delete(sessionTable, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  /// Replaces a session's messages with the remote conversation.
  Future<void> replaceMessages(
    int sessionId,
    List<({String role, String content, String? thinking, int createdAt})>
    messages, {
    required int? remoteParentId,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(
        messageTable,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      for (final message in messages) {
        await txn.insert(messageTable, {
          'session_id': sessionId,
          'role': message.role,
          'content': message.content,
          'thinking': message.thinking,
          'created_at': message.createdAt,
        });
      }
      await txn.update(
        sessionTable,
        {'remote_parent_id': remoteParentId},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  /// Updates the updated_at timestamp of a session.
  Future<void> touchSession(int sessionId) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      sessionTable,
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Deletes a chat session and all its messages.
  Future<void> deleteSession(int sessionId) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(
        messageTable,
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(sessionTable, where: 'id = ?', whereArgs: [sessionId]);
    });
  }

  /// Gets all messages in a chat session.
  Future<List<ChatMessage>> getMessages(int sessionId) async {
    final db = await _getDb();
    final rows = await db.query(
      messageTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  /// Inserts a message into a chat session.
  Future<int> insertMessage(
    int sessionId,
    String role,
    String content, {
    Uint8List? imageData,
    String? fileName,
    String? fileContent,
    String? thinking,
  }) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(messageTable, {
      'thinking': thinking,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'image_data': imageData,
      'file_name': fileName,
      'file_content': fileContent,
      'created_at': now,
    });
    await touchSession(sessionId);
    return id;
  }

  /// Clears all messages in a chat session.
  Future<void> clearSessionMessages(int sessionId) async {
    final db = await _getDb();
    await db.delete(
      messageTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await db.update(
      sessionTable,
      {'remote_id': null, 'remote_parent_id': null},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    await touchSession(sessionId);
  }
}
