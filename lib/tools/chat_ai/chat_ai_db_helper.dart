import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tool_lab/services/database_service.dart';
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
        currentVersion: 2,
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
        },
      );
    } catch (e) {
      debugPrint('[ChatAiDbHelper] Migration failed: $e');
    }
    return _cachedDb!;
  }

  /// Gets all chat sessions sorted by updated_at descending.
  Future<List<Map<String, dynamic>>> getSessions() async {
    final db = await _getDb();
    return await db.query(sessionTable, orderBy: 'updated_at DESC');
  }

  /// Creates a new chat session.
  Future<int> createSession(String title) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert(sessionTable, {
      'title': title,
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
  Future<List<Map<String, dynamic>>> getMessages(int sessionId) async {
    final db = await _getDb();
    return await db.query(
      messageTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  /// Inserts a message into a chat session.
  Future<int> insertMessage(
    int sessionId,
    String role,
    String content, {
    Uint8List? imageData,
  }) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(messageTable, {
      'session_id': sessionId,
      'role': role,
      'content': content,
      'image_data': imageData,
      'created_at': now,
    });
    await touchSession(sessionId);
    return id;
  }
}
