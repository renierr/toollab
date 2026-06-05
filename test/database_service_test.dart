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
    testWidgets('Tool database namespaces table names correctly', (
      WidgetTester tester,
    ) async {
      final dbService = DatabaseService.instance;
      final toolDb1 = await dbService.getToolDatabase('tool-one');
      final toolDb2 = await dbService.getToolDatabase('tool-two');

      expect(toolDb1.nameTable('history'), 'tool_tool_one_history');
      expect(toolDb2.nameTable('history'), 'tool_tool_two_history');
    });

    testWidgets(
      'Tool databases can create tables and insert/query/update/delete independently',
      (WidgetTester tester) async {
        final dbService = DatabaseService.instance;
        final toolDb1 = await dbService.getToolDatabase('tool_a');
        final toolDb2 = await dbService.getToolDatabase('tool_b');

        final tableA = toolDb1.nameTable('items');
        final tableB = toolDb2.nameTable('items');

        // Create table for tool A
        await toolDb1.execute('''
        CREATE TABLE IF NOT EXISTS $tableA (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT
        )
      ''');

        // Create table for tool B
        await toolDb2.execute('''
        CREATE TABLE IF NOT EXISTS $tableB (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          value INTEGER
        )
      ''');

        // Insert into Tool A
        final idA = await toolDb1.insert('items', {'name': 'Apple'});
        expect(idA, 1);

        // Insert into Tool B
        final idB = await toolDb2.insert('items', {'value': 42});
        expect(idB, 1);

        // Query Tool A
        final queryA = await toolDb1.query('items');
        expect(queryA.length, 1);
        expect(queryA.first['name'], 'Apple');

        // Query Tool B
        final queryB = await toolDb2.query('items');
        expect(queryB.length, 1);
        expect(queryB.first['value'], 42);

        // Update Tool A
        final updatedA = await toolDb1.update(
          'items',
          {'name': 'Banana'},
          where: 'id = ?',
          whereArgs: [idA],
        );
        expect(updatedA, 1);

        final queryA2 = await toolDb1.query('items');
        expect(queryA2.first['name'], 'Banana');

        // Delete from Tool A
        final deletedA = await toolDb1.delete(
          'items',
          where: 'id = ?',
          whereArgs: [idA],
        );
        expect(deletedA, 1);

        final queryA3 = await toolDb1.query('items');
        expect(queryA3.isEmpty, true);

        // Query B should still have its item
        final queryB2 = await toolDb2.query('items');
        expect(queryB2.length, 1);
      },
    );

    testWidgets('ToolDatabase supports transactions with namespaced executor', (
      WidgetTester tester,
    ) async {
      final dbService = DatabaseService.instance;
      final toolDb = await dbService.getToolDatabase('tool_txn');
      final table = toolDb.nameTable('logs');

      await toolDb.execute('''
        CREATE TABLE IF NOT EXISTS $table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          msg TEXT
        )
      ''');

      await toolDb.transaction((txn) async {
        await txn.insert('logs', {'msg': 'First'});
        await txn.insert('logs', {'msg': 'Second'});
      });

      final rows = await toolDb.query('logs');
      expect(rows.length, 2);
      expect(rows[0]['msg'], 'First');
      expect(rows[1]['msg'], 'Second');
    });

    testWidgets('ToolDatabase supports batch operations', (
      WidgetTester tester,
    ) async {
      final dbService = DatabaseService.instance;
      final toolDb = await dbService.getToolDatabase('tool_batch');
      final table = toolDb.nameTable('data');

      await toolDb.execute('''
        CREATE TABLE IF NOT EXISTS $table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          val TEXT
        )
      ''');

      final batch = toolDb.batch();
      batch.insert('data', {'val': 'A'});
      batch.insert('data', {'val': 'B'});
      batch.insert('data', {'val': 'C'});
      await batch.commit();

      final rows = await toolDb.query('data');
      expect(rows.length, 3);
      expect(rows.map((r) => r['val']).toList(), ['A', 'B', 'C']);
    });

    testWidgets('ToolDatabase supports safe schema migrations', (
      WidgetTester tester,
    ) async {
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
