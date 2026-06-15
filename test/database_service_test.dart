import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';

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
