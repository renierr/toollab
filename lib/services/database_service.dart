import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kReleaseMode, kProfileMode;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/core/tool_model.dart';

class DatabaseService {
  static const String _dbName = 'tool_lab.db';
  static const int _dbVersion = 2;
  static const String _tableFavorites = 'tool_favorites';
  static const String _tableSettings = 'tool_settings';
  static const String _tableRecentUsage = 'tool_recent_usage';

  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  Database? _database;

  /// Allows overriding the database path (e.g. to [inMemoryDatabasePath] for isolated tests).
  String? dbPathOverride;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Closes the database and resets the connection so it can be reinitialized.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path;
    if (dbPathOverride != null) {
      path = dbPathOverride!;
    } else {
      final appSupportDir = await getApplicationSupportDirectory();
      final modeSubdir = kReleaseMode
          ? ''
          : (kProfileMode ? 'profile' : 'debug');
      final docDir = Directory(p.join(appSupportDir.path, modeSubdir));
      if (!await docDir.exists()) {
        await docDir.create(recursive: true);
      }
      path = p.join(docDir.path, _dbName);
    }

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    try {
      await db.execute('PRAGMA journal_mode=WAL;');
    } catch (_) {}
    return db;
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

  /// Reads one setting [key] across every tool at once, keyed by tool id. Tools
  /// with no stored value are absent, so callers apply their own default.
  Future<Map<String, String>> getSettingForAllTools(String key) async {
    final db = await database;
    final rows = await db.query(
      _tableSettings,
      columns: ['tool_id', 'value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return {for (final r in rows) r['tool_id'] as String: r['value'] as String};
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

  /// Retrieves a namespaced database helper for a specific tool by its ID.
  Future<ToolDatabase> getToolDatabase(String toolId) async {
    final db = await database;
    return ToolDatabase(toolId, db);
  }

  /// Retrieves a namespaced database helper for a specific tool by its [ToolModel] configuration.
  Future<ToolDatabase> getToolDatabaseForConfig(ToolModel config) async {
    return getToolDatabase(config.id);
  }

  /// Reads the raw bytes of the active SQLite database file for backup/export.
  Future<Uint8List> getDatabaseBytes() async {
    final db = await database;
    try {
      await db.execute('PRAGMA wal_checkpoint(FULL);');
    } catch (_) {}
    final path = db.path;
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Database file does not exist');
    }
    return await file.readAsBytes();
  }

  Future<int> getDatabaseSize() async {
    final db = await database;
    final file = File(db.path);
    return await file.exists() ? await file.length() : 0;
  }

  /// Tables a valid ToolLab backup database must contain.
  static const Set<String> _requiredTables = {
    _tableFavorites,
    _tableSettings,
    _tableRecentUsage,
  };

  /// Validates that the file at [sourcePath] is a SQLite database compatible
  /// with ToolLab.
  ///
  /// Throws a [FormatException] if the file is not a valid SQLite database or
  /// is missing required tables. Does not touch the active database.
  Future<void> validateDatabaseFile(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw const FormatException('Selected file does not exist.');
    }

    // Every SQLite file begins with the 16-byte header "SQLite format 3\x00".
    const expectedHeader = <int>[
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, //
      0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
    ];
    final raf = await file.open();
    try {
      final headerBytes = await raf.read(expectedHeader.length);
      if (headerBytes.length < expectedHeader.length) {
        throw const FormatException(
          'File is too small to be a SQLite database.',
        );
      }
      for (var i = 0; i < expectedHeader.length; i++) {
        if (headerBytes[i] != expectedHeader[i]) {
          throw const FormatException('File is not a valid SQLite database.');
        }
      }
    } finally {
      await raf.close();
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    Database? probe;
    try {
      probe = await openDatabase(sourcePath, readOnly: true);
      final rows = await probe.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = rows.map((r) => r['name'] as String).toSet();
      final missing = _requiredTables.difference(tables);
      if (missing.isNotEmpty) {
        throw FormatException(
          'Incompatible database: missing tables ${missing.join(', ')}.',
        );
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Could not read database file: $e');
    } finally {
      await probe?.close();
    }
  }

  /// Replaces the active database file with the file at [sourcePath] after
  /// validating it.
  ///
  /// Closes and reopens the connection so the imported data takes effect
  /// (running any schema migrations). Throws if the file is invalid or
  /// incompatible.
  Future<void> importDatabaseFile(String sourcePath) async {
    await validateDatabaseFile(sourcePath);

    final db = await database;
    final path = db.path;
    await close();

    await File(sourcePath).copy(path);

    // Reopen so subsequent access uses the imported data.
    await database;
  }
}

/// A namespaced wrapper around a [DatabaseExecutor] (like [Database] or [Transaction])
/// that automatically prefixes table names with a tool-specific prefix to prevent conflicts.
class ToolDatabaseExecutor {
  final String toolId;
  final DatabaseExecutor executor;

  const ToolDatabaseExecutor(this.toolId, this.executor);

  /// Resolves a local table name into a namespaced table name.
  /// Use this to construct table names for raw SQL queries.
  String nameTable(String tableName) {
    final cleanToolId = toolId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final cleanTable = tableName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'tool_${cleanToolId}_$cleanTable';
  }

  /// Executes a raw SQL query.
  /// If using custom table names in raw SQL, use [nameTable] to obtain the correct namespaced table name.
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await executor.execute(sql, arguments);
  }

  /// Helper to insert a row into a namespaced table.
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return await executor.insert(
      nameTable(table),
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// Helper to query a namespaced table.
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await executor.query(
      nameTable(table),
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Helper to update rows in a namespaced table.
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return await executor.update(
      nameTable(table),
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// Helper to delete rows from a namespaced table.
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return await executor.delete(
      nameTable(table),
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Executes a raw INSERT query.
  /// If referencing tool-specific tables, construct the SQL using [nameTable].
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    return await executor.rawInsert(sql, arguments);
  }

  /// Executes a raw SELECT query.
  /// If referencing tool-specific tables, construct the SQL using [nameTable].
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return await executor.rawQuery(sql, arguments);
  }

  /// Executes a raw UPDATE query.
  /// If referencing tool-specific tables, construct the SQL using [nameTable].
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    return await executor.rawUpdate(sql, arguments);
  }

  /// Executes a raw DELETE query.
  /// If referencing tool-specific tables, construct the SQL using [nameTable].
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    return await executor.rawDelete(sql, arguments);
  }

  /// Creates a batch operation helper.
  ToolBatch batch() {
    final exec = executor;
    if (exec is Database) {
      return ToolBatch(toolId, exec.batch());
    } else if (exec is Transaction) {
      return ToolBatch(toolId, exec.batch());
    }
    throw UnsupportedError(
      'Batch operations are not supported on this executor.',
    );
  }
}

/// A namespaced database client wrapper for a specific tool.
class ToolDatabase extends ToolDatabaseExecutor {
  final Database _db;

  ToolDatabase(String toolId, this._db) : super(toolId, _db);

  /// Runs database operations inside a single SQLite transaction.
  ///
  /// The provided callback receives a [ToolDatabaseExecutor] which is also namespaced
  /// to the same tool ID.
  Future<T> transaction<T>(
    Future<T> Function(ToolDatabaseExecutor txn) action, {
    bool? exclusive,
  }) async {
    return await _db.transaction<T>((txn) async {
      final toolTxn = ToolDatabaseExecutor(toolId, txn);
      return await action(toolTxn);
    }, exclusive: exclusive);
  }

  /// Safely runs schema migrations for this tool's database tables.
  ///
  /// Checks the current stored schema version for this tool in the `tool_settings` table.
  /// If it is less than [currentVersion], [onMigrate] is called inside a transaction.
  Future<void> migrate({
    required int currentVersion,
    required Future<void> Function(
      ToolDatabaseExecutor db,
      int oldVersion,
      int newVersion,
    )
    onMigrate,
  }) async {
    await transaction((txn) async {
      final rows = await txn.executor.query(
        'tool_settings',
        columns: ['value'],
        where: 'tool_id = ? AND key = ?',
        whereArgs: [toolId, '_db_schema_version'],
        limit: 1,
      );

      final oldVersion = rows.isEmpty
          ? 0
          : (int.tryParse(rows.first['value'] as String? ?? '0') ?? 0);

      if (oldVersion < currentVersion) {
        await onMigrate(txn, oldVersion, currentVersion);
        await txn.executor.insert('tool_settings', {
          'tool_id': toolId,
          'key': '_db_schema_version',
          'value': currentVersion.toString(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}

/// A namespaced batch operation helper that automatically prefixes table names.
class ToolBatch {
  final String toolId;
  final Batch _batch;

  const ToolBatch(this.toolId, this._batch);

  /// Resolves a local table name into a namespaced table name.
  String nameTable(String tableName) {
    final cleanToolId = toolId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final cleanTable = tableName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'tool_${cleanToolId}_$cleanTable';
  }

  /// Executes a raw SQL query inside the batch.
  void execute(String sql, [List<Object?>? arguments]) {
    _batch.execute(sql, arguments);
  }

  /// Inserts a row inside the batch.
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _batch.insert(
      nameTable(table),
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// Updates rows inside the batch.
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _batch.update(
      nameTable(table),
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// Deletes rows inside the batch.
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _batch.delete(nameTable(table), where: where, whereArgs: whereArgs);
  }

  /// Commits the batch operations to the database.
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    return await _batch.commit(
      exclusive: exclusive,
      noResult: noResult,
      continueOnError: continueOnError,
    );
  }
}
