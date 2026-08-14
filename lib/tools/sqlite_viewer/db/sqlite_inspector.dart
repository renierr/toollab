import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'sql_identifier.dart';
import 'sqlite_models.dart';

/// Every sqflite call of the SQLite viewer lives here. The UI never talks to a
/// [Database] directly.
class SqliteInspector {
  static const String rowIdAlias = '_tl_rowid_';
  static const int maxFreeQueryRows = 2000;
  static const List<int> _magic = [
    0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, //
    0x66, 0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
  ];

  Database? _db;
  String? _path;
  bool _writable = false;

  bool get isOpen => _db != null;
  bool get isWritable => _writable;
  String? get path => _path;

  Database get _require {
    final db = _db;
    if (db == null) throw StateError('SqliteInspector: no database open.');
    return db;
  }

  /// Reads the 16-byte file header before handing the path to sqflite, so a
  /// non-database file fails with a clear reason instead of a native error.
  static Future<void> verifyIsSqliteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw SqliteOpenException(SqliteOpenFailure.missing, path);
    }
    if (await file.length() < _magic.length) {
      throw SqliteOpenException(SqliteOpenFailure.notSqlite, path);
    }
    final handle = await file.open();
    try {
      final header = await handle.read(_magic.length);
      for (var i = 0; i < _magic.length; i++) {
        if (header[i] != _magic[i]) {
          throw SqliteOpenException(SqliteOpenFailure.notSqlite, path);
        }
      }
    } finally {
      await handle.close();
    }
  }

  Future<void> open(String path, {bool writable = false}) async {
    await close();
    await verifyIsSqliteFile(path);
    try {
      _db = await openDatabase(path, readOnly: !writable);
      _path = path;
      _writable = writable;
    } on DatabaseException catch (e) {
      throw SqliteOpenException(
        e.isReadOnlyError() || e.isDatabaseClosedError()
            ? SqliteOpenFailure.locked
            : SqliteOpenFailure.unknown,
        e.toString(),
      );
    } catch (e) {
      throw SqliteOpenException(SqliteOpenFailure.unknown, e.toString());
    }
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _path = null;
    _writable = false;
    if (db == null) return;
    try {
      await db.close();
    } catch (e) {
      errorLog('SqliteInspector: close failed: $e');
    }
  }

  Future<T?> _pragma<T>(String name) async {
    try {
      final rows = await _require.rawQuery('PRAGMA $name');
      if (rows.isEmpty) return null;
      return rows.first.values.first as T?;
    } catch (e) {
      debugLog('SqliteInspector: PRAGMA $name failed: $e');
      return null;
    }
  }

  Future<DbOverview> readOverview() async {
    final db = _require;
    final path = _path!;
    final file = File(path);
    final size = await file.exists() ? await file.length() : 0;

    final versionRows = await db.rawQuery('SELECT sqlite_version() AS v');
    final counts = await db.rawQuery(
      'SELECT type, COUNT(*) AS c FROM sqlite_master GROUP BY type',
    );
    int countOf(String type) => counts
        .where((row) => row['type'] == type)
        .map((row) => (row['c'] as int?) ?? 0)
        .fold(0, (a, b) => a + b);

    return DbOverview(
      fileName: path.split(Platform.pathSeparator).last.split('/').last,
      filePath: path,
      fileSizeBytes: size,
      sqliteVersion: '${versionRows.first['v'] ?? ''}',
      pageSize: await _pragma<int>('page_size') ?? 0,
      pageCount: await _pragma<int>('page_count') ?? 0,
      freelistCount: await _pragma<int>('freelist_count') ?? 0,
      encoding: await _pragma<String>('encoding') ?? '',
      userVersion: await _pragma<int>('user_version') ?? 0,
      applicationId: await _pragma<int>('application_id') ?? 0,
      journalMode: await _pragma<String>('journal_mode') ?? '',
      autoVacuum: await _pragma<int>('auto_vacuum') ?? 0,
      tableCount: countOf('table'),
      viewCount: countOf('view'),
      indexCount: countOf('index'),
      triggerCount: countOf('trigger'),
    );
  }

  Future<String> integrityCheck() async {
    final rows = await _require.rawQuery('PRAGMA quick_check');
    return rows.map((row) => '${row.values.first}').join('\n');
  }

  Future<List<DbObject>> listObjects() async {
    final rows = await _require.rawQuery(
      "SELECT type, name, tbl_name, sql FROM sqlite_master "
      "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
    );
    return rows
        .map((row) {
          final type = _objectType('${row['type']}');
          if (type == null) return null;
          return DbObject(
            type: type,
            name: '${row['name']}',
            tableName: '${row['tbl_name']}',
            sql: row['sql'] as String?,
          );
        })
        .whereType<DbObject>()
        .toList();
  }

  DbObjectType? _objectType(String raw) => switch (raw) {
    'table' => DbObjectType.table,
    'view' => DbObjectType.view,
    'index' => DbObjectType.indexObject,
    'trigger' => DbObjectType.trigger,
    _ => null,
  };

  Future<TableSchema> readSchema(DbObject object) async {
    final db = _require;
    final quoted = quoteIdent(object.name);

    final columnRows = await db.rawQuery('PRAGMA table_info($quoted)');
    final columns = columnRows
        .map(
          (row) => ColumnInfo(
            cid: (row['cid'] as int?) ?? 0,
            name: '${row['name']}',
            declaredType: '${row['type'] ?? ''}',
            notNull: ((row['notnull'] as int?) ?? 0) != 0,
            defaultValue: row['dflt_value']?.toString(),
            primaryKeyIndex: (row['pk'] as int?) ?? 0,
          ),
        )
        .toList();

    final indexes = <IndexInfo>[];
    final foreignKeys = <ForeignKeyInfo>[];
    if (object.type == DbObjectType.table) {
      final indexRows = await db.rawQuery('PRAGMA index_list($quoted)');
      for (final row in indexRows) {
        final name = '${row['name']}';
        final infoRows = await db.rawQuery(
          'PRAGMA index_info(${quoteIdent(name)})',
        );
        indexes.add(
          IndexInfo(
            name: name,
            unique: ((row['unique'] as int?) ?? 0) != 0,
            origin: '${row['origin'] ?? ''}',
            partial: ((row['partial'] as int?) ?? 0) != 0,
            columns: infoRows
                .map((info) => '${info['name'] ?? ''}')
                .where((name) => name.isNotEmpty)
                .toList(),
          ),
        );
      }

      final fkRows = await db.rawQuery('PRAGMA foreign_key_list($quoted)');
      for (final row in fkRows) {
        foreignKeys.add(
          ForeignKeyInfo(
            fromColumn: '${row['from'] ?? ''}',
            targetTable: '${row['table'] ?? ''}',
            targetColumn: '${row['to'] ?? ''}',
            onUpdate: '${row['on_update'] ?? ''}',
            onDelete: '${row['on_delete'] ?? ''}',
          ),
        );
      }
    }

    return TableSchema(
      object: object,
      columns: columns,
      indexes: indexes,
      foreignKeys: foreignKeys,
    );
  }

  /// Builds a case-insensitive contains-filter across every column. The term is
  /// always bound, never interpolated.
  (String, List<Object?>) _searchClause(
    List<ColumnInfo> columns,
    String? search,
  ) {
    final term = search?.trim() ?? '';
    if (term.isEmpty || columns.isEmpty) return ('', const []);
    final conditions = columns
        .map((c) => 'CAST(${quoteIdent(c.name)} AS TEXT) LIKE ? ESCAPE \'\\\'')
        .join(' OR ');
    final escaped = term
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final args = List<Object?>.filled(columns.length, '%$escaped%');
    return (' WHERE ($conditions)', args);
  }

  Future<TablePage> fetchPage({
    required DbObject object,
    required List<ColumnInfo> columns,
    required int offset,
    required int limit,
    String? sortColumn,
    bool descending = false,
    String? search,
  }) async {
    final db = _require;
    final quoted = quoteIdent(object.name);
    final (where, args) = _searchClause(columns, search);

    final countRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $quoted$where',
      args,
    );
    final total = (countRows.first['c'] as int?) ?? 0;
    final safeOffset = offset >= total ? 0 : offset;

    final select = object.isEditable ? 'rowid AS $rowIdAlias, *' : '*';
    final order = sortColumn == null
        ? ''
        : ' ORDER BY ${quoteIdent(sortColumn)} ${descending ? 'DESC' : 'ASC'}';
    final rows = await db.rawQuery(
      'SELECT $select FROM $quoted$where$order LIMIT ? OFFSET ?',
      [...args, limit, safeOffset],
    );

    final names = columns.isNotEmpty
        ? columns.map((c) => c.name).toList()
        : (rows.isEmpty
              ? <String>[]
              : rows.first.keys.where((k) => k != rowIdAlias).toList());

    return TablePage(
      columns: names,
      rows: rows.map((row) => names.map((n) => row[n]).toList()).toList(),
      rowIds: rows.map((row) => row[rowIdAlias] as int?).toList(),
      offset: safeOffset,
      totalRows: total,
    );
  }

  Future<QueryResult> runSql(String sql) async {
    final db = _require;
    final kind = classifySql(sql);
    final watch = Stopwatch()..start();

    if (kind == SqlStatementKind.read) {
      final rows = await db.rawQuery(sql);
      watch.stop();
      final limited = rows.length > maxFreeQueryRows
          ? rows.sublist(0, maxFreeQueryRows)
          : rows;
      final names = limited.isEmpty
          ? <String>[]
          : limited.first.keys.toList(growable: false);
      return QueryResult(
        kind: kind,
        columns: names,
        rows: limited.map((row) => names.map((n) => row[n]).toList()).toList(),
        affectedRows: 0,
        elapsedMs: watch.elapsedMilliseconds,
        truncated: rows.length > maxFreeQueryRows,
      );
    }

    final affected = kind == SqlStatementKind.write
        ? await db.rawUpdate(sql)
        : await _executeReturningZero(db, sql);
    watch.stop();
    return QueryResult(
      kind: kind,
      columns: const [],
      rows: const [],
      affectedRows: affected,
      elapsedMs: watch.elapsedMilliseconds,
    );
  }

  Future<int> _executeReturningZero(Database db, String sql) async {
    await db.execute(sql);
    return 0;
  }

  Future<void> updateCell({
    required String table,
    required String column,
    required int rowId,
    required Object? value,
  }) async {
    await _require.rawUpdate(
      'UPDATE ${quoteIdent(table)} SET ${quoteIdent(column)} = ? '
      'WHERE rowid = ?',
      [value, rowId],
    );
  }

  Future<void> deleteRow({required String table, required int rowId}) async {
    await _require.rawDelete(
      'DELETE FROM ${quoteIdent(table)} WHERE rowid = ?',
      [rowId],
    );
  }

  Future<void> insertRow({
    required String table,
    required Map<String, Object?> values,
  }) async {
    if (values.isEmpty) {
      await _require.execute('INSERT INTO ${quoteIdent(table)} DEFAULT VALUES');
      return;
    }
    final columns = values.keys.map(quoteIdent).join(', ');
    final placeholders = List.filled(values.length, '?').join(', ');
    await _require.rawInsert(
      'INSERT INTO ${quoteIdent(table)} ($columns) VALUES ($placeholders)',
      values.values.toList(),
    );
  }
}
