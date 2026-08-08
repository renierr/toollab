import 'dart:math';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'config.dart';
import 'grocery_item.dart';

class GroceryListDbHelper {
  static const String tableName = 'items';
  static const String historyTableName = 'item_history';

  GroceryListDbHelper._privateConstructor();
  static final GroceryListDbHelper instance =
      GroceryListDbHelper._privateConstructor();

  ToolDatabase? _cachedDb;

  Future<ToolDatabase> _getDb() async {
    if (_cachedDb != null) return _cachedDb!;
    _cachedDb = await DatabaseService.instance.getToolDatabase(
      GroceryListTool.config.id,
    );
    try {
      await _cachedDb!.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(tableName)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                short_id TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                amount REAL NOT NULL DEFAULT 1.0,
                unit TEXT NOT NULL,
                checked INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(historyTableName)} (
                name TEXT PRIMARY KEY,
                count INTEGER NOT NULL DEFAULT 1
              )
            ''');
          }
        },
      );
    } catch (e) {
      errorLog('[GroceryListDbHelper] Migration failed, using fallback: $e');
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

  Future<List<GroceryItem>> getActiveItems() async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'deleted = 0',
      orderBy: 'checked ASC, name ASC',
    );
    return rows.map((r) => GroceryItem.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getSyncRecords() async {
    final db = await _getDb();
    return await db.query(
      tableName,
      columns: ['short_id', 'updated_at', 'deleted'],
    );
  }

  Future<GroceryItem?> getItemByShortId(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GroceryItem.fromMap(rows.first);
  }

  Future<GroceryItem?> getItemById(int id) async {
    final db = await _getDb();
    final rows = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GroceryItem.fromMap(rows.first);
  }

  Future<int> saveItem(GroceryItem item) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (item.id != null) {
      final existing = await getItemById(item.id!);
      final shortId = existing?.shortId ?? item.shortId;
      final existingUpdatedAt = existing?.updatedAt ?? 0;
      final updateUpdatedAt = max(now, existingUpdatedAt + 1);

      final updated = item.copyWith(
        shortId: shortId,
        updatedAt: updateUpdatedAt,
        synced: false,
      );

      await db.update(
        tableName,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      return item.id!;
    } else {
      final shortId = item.shortId.isEmpty ? generateShortId() : item.shortId;
      final inserted = item.copyWith(
        shortId: shortId,
        createdAt: item.createdAt == 0 ? now : item.createdAt,
        updatedAt: item.updatedAt == 0 ? now : item.updatedAt,
        synced: false,
      );

      final newId = await db.insert(tableName, inserted.toMap());
      await addToHistory(item.name);
      return newId;
    }
  }

  Future<void> softDeleteItem(int id) async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getItemById(id);
    if (existing != null) {
      final existingUpdatedAt = existing.updatedAt;
      final deleteUpdatedAt = max(now, existingUpdatedAt + 1);
      await db.update(
        tableName,
        {'deleted': 1, 'updated_at': deleteUpdatedAt, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> hardDeleteItem(String shortId) async {
    final db = await _getDb();
    await db.delete(tableName, where: 'short_id = ?', whereArgs: [shortId]);
  }

  Future<void> markSynced(String shortId) async {
    final db = await _getDb();
    await db.update(
      tableName,
      {'synced': 1},
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<void> clearCheckedItems() async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = await getActiveItems();
    final checked = items.where((i) => i.checked);
    for (final item in checked) {
      if (item.id != null) {
        final deleteUpdatedAt = max(now, item.updatedAt + 1);
        await db.update(
          tableName,
          {'deleted': 1, 'updated_at': deleteUpdatedAt, 'synced': 0},
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
    }
  }

  Future<void> reAddCheckedItems() async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = await getActiveItems();
    final checked = items.where((i) => i.checked);
    for (final item in checked) {
      if (item.id != null) {
        final updateUpdatedAt = max(now, item.updatedAt + 1);
        await db.update(
          tableName,
          {'checked': 0, 'updated_at': updateUpdatedAt, 'synced': 0},
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await _getDb();
    return await db.query(historyTableName, orderBy: 'count DESC');
  }

  Future<void> addToHistory(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return;

    final db = await _getDb();
    await db.transaction((txn) async {
      final rows = await txn.query(
        historyTableName,
        where: 'name = ?',
        whereArgs: [normalized],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final count = (rows.first['count'] as int? ?? 1) + 1;
        await txn.update(
          historyTableName,
          {'count': count},
          where: 'name = ?',
          whereArgs: [normalized],
        );
      } else {
        await txn.insert(historyTableName, {'name': normalized, 'count': 1});
      }
    });
  }

  Future<Map<String, int>> importItems(List<GroceryItem> items) async {
    final db = await _getDb();
    final existingItems = await getActiveItems();
    final existingShortIds = existingItems.map((i) => i.shortId).toSet();

    int imported = 0;
    int skipped = 0;

    await db.transaction((txn) async {
      for (final item in items) {
        final shortId = item.shortId.isEmpty ? generateShortId() : item.shortId;
        if (existingShortIds.contains(shortId)) {
          skipped++;
          continue;
        }

        final inserted = item.copyWith(
          id: null,
          shortId: shortId,
          createdAt: item.createdAt == 0
              ? DateTime.now().millisecondsSinceEpoch
              : item.createdAt,
          updatedAt: item.updatedAt == 0
              ? DateTime.now().millisecondsSinceEpoch
              : item.updatedAt,
          synced: false,
        );

        await txn.insert(tableName, inserted.toMap());
        existingShortIds.add(shortId);
        imported++;
      }
    });

    return {'imported': imported, 'skipped': skipped};
  }

  Future<void> savePulledItem({
    required String shortId,
    required String name,
    required double amount,
    required String unit,
    required bool checked,
    required int createdAt,
    required int updatedAt,
    required bool deleted,
  }) async {
    final db = await _getDb();
    if (deleted) {
      await hardDeleteItem(shortId);
      return;
    }

    final existing = await getItemByShortId(shortId);
    if (existing != null) {
      await db.update(
        tableName,
        {
          'name': name,
          'amount': amount,
          'unit': unit,
          'checked': checked ? 1 : 0,
          'created_at': createdAt,
          'updated_at': updatedAt,
          'deleted': 0,
          'synced': 1,
        },
        where: 'short_id = ?',
        whereArgs: [shortId],
      );
    } else {
      await db.insert(tableName, {
        'short_id': shortId,
        'name': name,
        'amount': amount,
        'unit': unit,
        'checked': checked ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'deleted': 0,
        'synced': 1,
      });
    }
  }
}
