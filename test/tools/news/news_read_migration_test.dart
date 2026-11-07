import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/news/config.dart';
import 'package:tool_lab/tools/news/news_db_helper.dart';
import 'package:tool_lab/tools/news/news_sync_delegate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  tearDownAll(() => DatabaseService.instance.close());

  test('existing recent article reads are migrated for sync', () async {
    final db = await DatabaseService.instance.getToolDatabase(
      NewsTool.config.id,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.migrate(
      currentVersion: 1,
      onMigrate: (txn, _, _) async {
        await txn.execute(
          'CREATE TABLE ${txn.nameTable('sources')} (short_id TEXT PRIMARY KEY, title TEXT NOT NULL, feed_url TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
        );
        await txn.execute(
          'CREATE TABLE ${txn.nameTable('articles')} (guid_key TEXT PRIMARY KEY, read_at INTEGER)',
        );
        await txn.insert('articles', {
          'guid_key': 'recent',
          'read_at': now - 1234,
        });
        await txn.insert('articles', {
          'guid_key': 'old',
          'read_at': now - NewsDbHelper.readRetentionMs - 1000,
        });
      },
    );
    final sync = NewsSyncDelegate();
    final records = await sync.getLocalSyncRecords();
    final bucket = records.singleWhere(
      (record) =>
          (record['id'] as String).startsWith(NewsDbHelper.readBucketPrefix),
    );
    final data = await sync.getLocalRecordData(bucket['id'] as String);
    expect(data!['reads'], {'recent': now - 1234});
  });
}
