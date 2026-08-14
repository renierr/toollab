enum DbObjectType { table, view, indexObject, trigger }

enum SqlStatementKind { read, write, schema, unknown }

class SqliteOpenException implements Exception {
  final SqliteOpenFailure failure;
  final String? detail;

  SqliteOpenException(this.failure, [this.detail]);

  @override
  String toString() => 'SqliteOpenException($failure, $detail)';
}

enum SqliteOpenFailure { missing, notSqlite, locked, unknown }

class DbObject {
  final DbObjectType type;
  final String name;
  final String tableName;
  final String? sql;

  const DbObject({
    required this.type,
    required this.name,
    required this.tableName,
    this.sql,
  });

  /// Rowid tables can be addressed by `rowid`, which is what makes cell edits
  /// and row deletes possible. Views and WITHOUT ROWID tables cannot.
  bool get isEditable =>
      type == DbObjectType.table &&
      !(sql ?? '').toUpperCase().contains('WITHOUT ROWID');

  bool get isBrowsable =>
      type == DbObjectType.table || type == DbObjectType.view;
}

class ColumnInfo {
  final int cid;
  final String name;
  final String declaredType;
  final bool notNull;
  final String? defaultValue;
  final int primaryKeyIndex;

  const ColumnInfo({
    required this.cid,
    required this.name,
    required this.declaredType,
    required this.notNull,
    required this.defaultValue,
    required this.primaryKeyIndex,
  });

  bool get isPrimaryKey => primaryKeyIndex > 0;
}

class IndexInfo {
  final String name;
  final bool unique;
  final String origin;
  final bool partial;
  final List<String> columns;

  const IndexInfo({
    required this.name,
    required this.unique,
    required this.origin,
    required this.partial,
    required this.columns,
  });
}

class ForeignKeyInfo {
  final String fromColumn;
  final String targetTable;
  final String targetColumn;
  final String onUpdate;
  final String onDelete;

  const ForeignKeyInfo({
    required this.fromColumn,
    required this.targetTable,
    required this.targetColumn,
    required this.onUpdate,
    required this.onDelete,
  });
}

class TableSchema {
  final DbObject object;
  final List<ColumnInfo> columns;
  final List<IndexInfo> indexes;
  final List<ForeignKeyInfo> foreignKeys;

  const TableSchema({
    required this.object,
    required this.columns,
    required this.indexes,
    required this.foreignKeys,
  });
}

class DbOverview {
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final String sqliteVersion;
  final int pageSize;
  final int pageCount;
  final int freelistCount;
  final String encoding;
  final int userVersion;
  final int applicationId;
  final String journalMode;
  final int autoVacuum;
  final int tableCount;
  final int viewCount;
  final int indexCount;
  final int triggerCount;

  const DbOverview({
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.sqliteVersion,
    required this.pageSize,
    required this.pageCount,
    required this.freelistCount,
    required this.encoding,
    required this.userVersion,
    required this.applicationId,
    required this.journalMode,
    required this.autoVacuum,
    required this.tableCount,
    required this.viewCount,
    required this.indexCount,
    required this.triggerCount,
  });
}

/// One page of rows. [rowIds] holds the SQLite `rowid` per row when the source
/// supports it, so a cell edit can address its row unambiguously.
class TablePage {
  final List<String> columns;
  final List<List<Object?>> rows;
  final List<int?> rowIds;
  final int offset;
  final int totalRows;

  const TablePage({
    required this.columns,
    required this.rows,
    required this.rowIds,
    required this.offset,
    required this.totalRows,
  });

  static const empty = TablePage(
    columns: [],
    rows: [],
    rowIds: [],
    offset: 0,
    totalRows: 0,
  );
}

/// Outcome of a free-form statement: either a result set or an affected count.
class QueryResult {
  final SqlStatementKind kind;
  final List<String> columns;
  final List<List<Object?>> rows;
  final int affectedRows;
  final int elapsedMs;
  final bool truncated;

  const QueryResult({
    required this.kind,
    required this.columns,
    required this.rows,
    required this.affectedRows,
    required this.elapsedMs,
    this.truncated = false,
  });

  bool get isResultSet => kind == SqlStatementKind.read;
}

class InternalDbEntry {
  final String name;
  final String path;
  final int sizeBytes;
  final bool isLiveAppDatabase;

  const InternalDbEntry({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.isLiveAppDatabase,
  });
}
