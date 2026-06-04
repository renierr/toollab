import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  static const String _dbName = 'tool_lab.db';
  static const int _dbVersion = 2;
  static const String _tableFavorites = 'tool_favorites';
  static const String _tableSettings = 'tool_settings';
  static const String _tableRecentUsage = 'tool_recent_usage';

  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docDir = await getApplicationSupportDirectory();
    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }
    final path = p.join(docDir.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableFavorites (
        tool_id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableSettings (
        tool_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (tool_id, key)
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tableRecentUsage (
        tool_id TEXT PRIMARY KEY,
        last_used_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE $_tableRecentUsage (
          tool_id TEXT PRIMARY KEY,
          last_used_at INTEGER NOT NULL
        )
      ''');
    }
  }

  Future<Set<String>> getFavoriteIds() async {
    final db = await database;
    final rows = await db.query(_tableFavorites);
    return rows.map((r) => r['tool_id'] as String).toSet();
  }

  Future<bool> isFavorite(String toolId) async {
    final db = await database;
    final rows = await db.query(
      _tableFavorites,
      where: 'tool_id = ?',
      whereArgs: [toolId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> setFavorite(String toolId, bool favorite) async {
    final db = await database;
    if (favorite) {
      await db.insert(_tableFavorites, {
        'tool_id': toolId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        _tableFavorites,
        where: 'tool_id = ?',
        whereArgs: [toolId],
      );
    }
  }

  Future<Map<String, int>> getRecentTimestamps() async {
    final db = await database;
    final rows = await db.query(_tableRecentUsage);
    return {
      for (final r in rows) r['tool_id'] as String: r['last_used_at'] as int,
    };
  }

  Future<void> touchToolUsage(String toolId) async {
    final db = await database;
    await db.insert(_tableRecentUsage, {
      'tool_id': toolId,
      'last_used_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String toolId, String key) async {
    final db = await database;
    final rows = await db.query(
      _tableSettings,
      where: 'tool_id = ? AND key = ?',
      whereArgs: [toolId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setSetting(String toolId, String key, String value) async {
    final db = await database;
    await db.insert(_tableSettings, {
      'tool_id': toolId,
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings(String toolId) async {
    final db = await database;
    final rows = await db.query(
      _tableSettings,
      where: 'tool_id = ?',
      whereArgs: [toolId],
    );
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> deleteSetting(String toolId, String key) async {
    final db = await database;
    await db.delete(
      _tableSettings,
      where: 'tool_id = ? AND key = ?',
      whereArgs: [toolId, key],
    );
  }

  Future<void> deleteAllSettings(String toolId) async {
    final db = await database;
    await db.delete(_tableSettings, where: 'tool_id = ?', whereArgs: [toolId]);
  }
}
