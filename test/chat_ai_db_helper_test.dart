import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/chat_ai/chat_ai_db_helper.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  group('ChatAiDbHelper Tests', () {
    test('Can create sessions and messages and delete them', () async {
      final dbHelper = ChatAiDbHelper.instance;

      // 1. Initially sessions must be empty
      var sessions = await dbHelper.getSessions();
      expect(sessions.isEmpty, true);

      // 2. Create a session
      final sessionId = await dbHelper.createSession('Test Chat');
      expect(sessionId > 0, true);

      sessions = await dbHelper.getSessions();
      expect(sessions.length, 1);
      expect(sessions.first['title'], 'Test Chat');

      // 3. Insert messages
      final userMsgId = await dbHelper.insertMessage(
        sessionId,
        'user',
        'Hello AI!',
      );
      final aiMsgId = await dbHelper.insertMessage(
        sessionId,
        'model',
        'Hello User!',
      );

      expect(userMsgId > 0, true);
      expect(aiMsgId > 0, true);

      final messages = await dbHelper.getMessages(sessionId);
      expect(messages.length, 2);
      expect(messages[0]['role'], 'user');
      expect(messages[0]['content'], 'Hello AI!');
      expect(messages[1]['role'], 'model');
      expect(messages[1]['content'], 'Hello User!');

      // 4. Update session title
      await dbHelper.updateSessionTitle(sessionId, 'Updated Chat');
      sessions = await dbHelper.getSessions();
      expect(sessions.first['title'], 'Updated Chat');

      // 5. Delete session
      await dbHelper.deleteSession(sessionId);
      sessions = await dbHelper.getSessions();
      expect(sessions.isEmpty, true);

      final orphanedMessages = await dbHelper.getMessages(sessionId);
      expect(orphanedMessages.isEmpty, true);
    });
  });
}
