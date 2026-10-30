import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';

class _AndroidPragmaExecutor extends Fake implements DatabaseExecutor {
  _AndroidPragmaExecutor(this.result);

  final List<Map<String, Object?>> result;
  final List<String> queries = [];

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    queries.add(sql);
    return result;
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  group('ToolDatabase Namespace Tests', () {
    test(
      'secure deletion uses a query and verifies the returned value',
      () async {
        final executor = _AndroidPragmaExecutor([
          {'secure_delete': 1},
        ]);
        final txn = ToolDatabaseExecutor('test', executor);
        await txn.enableSecureDelete();
        expect(executor.queries, ['PRAGMA secure_delete = ON']);

        final disabled = ToolDatabaseExecutor(
          'test',
          _AndroidPragmaExecutor([
            {'secure_delete': 0},
          ]),
        );
        await expectLater(disabled.enableSecureDelete(), throwsStateError);

        final missing = ToolDatabaseExecutor(
          'test',
          _AndroidPragmaExecutor([]),
        );
        await expectLater(missing.enableSecureDelete(), throwsStateError);
      },
    );

    test('secure deletion is enabled on the transaction connection', () async {
      final db = await DatabaseService.instance.getToolDatabase('secure_test');
      await db.transaction((txn) async {
        await txn.enableSecureDelete();
        final rows = await txn.rawQuery('PRAGMA secure_delete');
        expect(rows.single['secure_delete'], 1);
      });
    });
    test('Tool database namespaces table names correctly', () async {
      final dbService = DatabaseService.instance;
      final toolDb1 = await dbService.getToolDatabase('tool-one');
      final toolDb2 = await dbService.getToolDatabase('tool-two');

      expect(toolDb1.nameTable('history'), 'tool_tool_one_history');
      expect(toolDb2.nameTable('history'), 'tool_tool_two_history');
    });

    test('ToolDatabase supports safe schema migrations', () async {
      final dbService = DatabaseService.instance;
      final toolDb = await dbService.getToolDatabase('tool_migration');
      final table = toolDb.nameTable('test');

      // Helper to clear existing DB version in settings for clean test run
      await dbService.deleteSetting('tool_migration', '_db_schema_version');
      await toolDb.execute('DROP TABLE IF EXISTS $table');

      // First migration: v1 (creates table)
      await toolDb.migrate(
        currentVersion: 1,
        onMigrate: (db, oldVersion, newVersion) async {
          expect(oldVersion, 0);
          expect(newVersion, 1);
          await db.execute('''
            CREATE TABLE $table (
              id INTEGER PRIMARY KEY,
              name TEXT
            )
          ''');
        },
      );

      // Verify table created
      await toolDb.insert('test', {'id': 1, 'name': 'Test'});

      // Second migration: v2 (adds field 'age')
      await toolDb.migrate(
        currentVersion: 2,
        onMigrate: (db, oldVersion, newVersion) async {
          expect(oldVersion, 1);
          expect(newVersion, 2);
          await db.execute('ALTER TABLE $table ADD COLUMN age INTEGER');
        },
      );

      // Verify we can insert new column
      await toolDb.update(
        'test',
        {'name': 'Updated', 'age': 30},
        where: 'id = ?',
        whereArgs: [1],
      );

      final rows = await toolDb.query('test');
      expect(rows.length, 1);
      expect(rows.first['name'], 'Updated');
      expect(rows.first['age'], 30);
    });
  });
}
