import 'sqlite_models.dart';

/// Quotes an identifier for interpolation into SQL. Values never go through
/// here — they are always bound as `?` parameters.
String quoteIdent(String name) => '"${name.replaceAll('"', '""')}"';

final _lineComment = RegExp(r'--[^\n]*');
final _blockComment = RegExp(r'/\*.*?\*/', dotAll: true);
final _leadingWord = RegExp(r'^[A-Za-z]+');

const _readKeywords = {'SELECT', 'WITH', 'EXPLAIN', 'VALUES'};
const _writeKeywords = {'INSERT', 'UPDATE', 'DELETE', 'REPLACE'};
const _schemaKeywords = {
  'CREATE',
  'DROP',
  'ALTER',
  'VACUUM',
  'REINDEX',
  'ATTACH',
  'DETACH',
  'ANALYZE',
  'BEGIN',
  'COMMIT',
  'ROLLBACK',
  'SAVEPOINT',
  'RELEASE',
};

String stripSqlComments(String sql) =>
    sql.replaceAll(_blockComment, ' ').replaceAll(_lineComment, ' ');

/// Classifies a statement by its leading keyword so read-only mode can refuse
/// anything that could modify the database.
SqlStatementKind classifySql(String sql) {
  final trimmed = stripSqlComments(sql).trim();
  if (trimmed.isEmpty) return SqlStatementKind.unknown;

  final match = _leadingWord.firstMatch(trimmed);
  if (match == null) return SqlStatementKind.unknown;
  final keyword = match.group(0)!.toUpperCase();

  // A bare `PRAGMA x` reads; `PRAGMA x = y` changes the database.
  if (keyword == 'PRAGMA') {
    return trimmed.contains('=')
        ? SqlStatementKind.schema
        : SqlStatementKind.read;
  }
  if (_readKeywords.contains(keyword)) return SqlStatementKind.read;
  if (_writeKeywords.contains(keyword)) return SqlStatementKind.write;
  if (_schemaKeywords.contains(keyword)) return SqlStatementKind.schema;
  return SqlStatementKind.unknown;
}

bool isReadOnlyStatement(String sql) =>
    classifySql(sql) == SqlStatementKind.read;
