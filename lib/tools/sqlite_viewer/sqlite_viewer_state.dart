import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/syntax/syntax_highlighter.dart';
import 'package:tool_lab/helpers/syntax/textmate_engine.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

import 'db/db_snapshot.dart';
import 'db/sql_identifier.dart';
import 'db/sqlite_inspector.dart';
import 'db/sqlite_models.dart';

const List<int> kSqliteViewerPageSizes = [25, 50, 100, 250];

const int kSqliteViewerTabCount = 3;

class SqliteViewerState extends ChangeNotifier {
  static const String _sqlLanguage = 'sql';
  static const int dataTabIndex = 1;

  final SqliteInspector _inspector = SqliteInspector();
  TempFileScope? _scope;

  String? _displayName;
  String? _originalPath;
  String? _workingPath;
  bool _isTempCopy = false;
  bool _isInternal = false;
  bool _editMode = false;
  bool _hasEdits = false;
  bool _isBusy = false;
  int _tabIndex = 0;

  SqliteOpenFailure? _openFailure;
  String? _openDetail;

  DbOverview? _overview;
  List<DbObject> _objects = const [];
  DbObject? _selected;
  TableSchema? _schema;
  TablePage _page = TablePage.empty;
  String? _integrityResult;

  int _pageSize = 100;
  int _offset = 0;
  String? _sortColumn;
  bool _sortDescending = false;
  String _search = '';
  Timer? _searchDebounce;

  String _sql = '';
  QueryResult? _queryResult;
  String? _queryError;
  bool _isRunningQuery = false;
  List<int> _sqlTokens = const [];
  List<String> _sqlScopes = const [];
  Timer? _highlightDebounce;

  List<InternalDbEntry> _internalDatabases = const [];
  bool _internalScanned = false;

  bool get isOpen => _inspector.isOpen;
  String? get displayName => _displayName;
  String? get originalPath => _originalPath;
  String? get workingPath => _workingPath;
  bool get isTempCopy => _isTempCopy;
  bool get isInternal => _isInternal;
  bool get editMode => _editMode;
  bool get canEnableEditMode => isOpen && !_isInternal;
  bool get hasEdits => _hasEdits;
  bool get isBusy => _isBusy;
  int get tabIndex => _tabIndex;
  SqliteOpenFailure? get openFailure => _openFailure;
  String? get openDetail => _openDetail;

  DbOverview? get overview => _overview;
  List<DbObject> get objects => _objects;
  DbObject? get selected => _selected;
  TableSchema? get schema => _schema;
  TablePage get page => _page;
  String? get integrityResult => _integrityResult;

  int get pageSize => _pageSize;
  int get offset => _offset;
  String? get sortColumn => _sortColumn;
  bool get sortDescending => _sortDescending;
  String get search => _search;

  String get sql => _sql;
  QueryResult? get queryResult => _queryResult;
  String? get queryError => _queryError;
  bool get isRunningQuery => _isRunningQuery;
  List<int> get sqlTokens => _sqlTokens;
  List<String> get sqlScopes => _sqlScopes;

  List<InternalDbEntry> get internalDatabases => _internalDatabases;

  List<DbObject> objectsOfType(DbObjectType type) =>
      _objects.where((o) => o.type == type).toList();

  void attachScope(TempFileScope scope) => _scope = scope;

  void setTabIndex(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Opening
  // ---------------------------------------------------------------------------

  Future<void> scanInternalDatabases({bool force = false}) async {
    if (_internalScanned && !force) return;
    _internalScanned = true;
    _internalDatabases = await listInternalDatabases();
    notifyListeners();
  }

  /// Opens a user-picked file. On Android the picker already streamed the file
  /// into the temp session dir, so [isSnapshot] marks the working file as a copy
  /// whose edits never reach the original.
  Future<void> openFile(
    String path,
    String name, {
    bool isSnapshot = false,
  }) async {
    await _openPath(
      workingPath: path,
      originalPath: path,
      name: name,
      isTempCopy: isSnapshot || _isInsideTempSession(path),
      isInternal: false,
    );
  }

  /// Opens one of ToolLab's own databases. Always a snapshot copy so the live
  /// connection is never disturbed, and always read-only.
  Future<void> openInternal(InternalDbEntry entry) async {
    final scope = _scope;
    if (scope == null) return;
    _setBusy(true);
    try {
      final copy = await copyDatabaseSnapshot(scope, entry.path);
      await _openPath(
        workingPath: copy,
        originalPath: entry.path,
        name: entry.name,
        isTempCopy: true,
        isInternal: true,
        keepBusy: true,
      );
    } catch (e) {
      _openFailure = SqliteOpenFailure.unknown;
      _openDetail = e.toString();
      errorLog('SqliteViewer: internal open failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openPath({
    required String workingPath,
    required String originalPath,
    required String name,
    required bool isTempCopy,
    required bool isInternal,
    bool keepBusy = false,
  }) async {
    if (!keepBusy) _setBusy(true);
    _openFailure = null;
    _openDetail = null;
    try {
      await _inspector.open(workingPath);
      _displayName = name;
      _workingPath = workingPath;
      _originalPath = originalPath;
      _isTempCopy = isTempCopy;
      _isInternal = isInternal;
      _editMode = false;
      _hasEdits = false;
      _tabIndex = 0;
      _resetQuery();
      unawaited(SyntaxHighlighter.preload(const [_sqlLanguage]));
      await _reloadStructure();
    } on SqliteOpenException catch (e) {
      _openFailure = e.failure;
      _openDetail = e.detail;
      await _inspector.close();
      _clearDocument();
    } catch (e) {
      _openFailure = SqliteOpenFailure.unknown;
      _openDetail = e.toString();
      await _inspector.close();
      _clearDocument();
    } finally {
      if (!keepBusy) {
        _setBusy(false);
      } else {
        notifyListeners();
      }
    }
  }

  bool _isInsideTempSession(String path) =>
      path.replaceAll('\\', '/').contains('/tool_lab/');

  Future<void> _reloadStructure() async {
    _overview = await _inspector.readOverview();
    _objects = await _inspector.listObjects();
    _integrityResult = null;
    final firstTable = _objects.where((o) => o.isBrowsable).firstOrNull;
    if (firstTable != null) {
      await _loadObject(firstTable);
    } else {
      _selected = null;
      _schema = null;
      _page = TablePage.empty;
    }
  }

  Future<void> closeDb() async {
    _highlightDebounce?.cancel();
    _searchDebounce?.cancel();
    await _inspector.close();
    _clearDocument();
    notifyListeners();
  }

  void _clearDocument() {
    _displayName = null;
    _workingPath = null;
    _originalPath = null;
    _isTempCopy = false;
    _isInternal = false;
    _editMode = false;
    _hasEdits = false;
    _tabIndex = 0;
    _overview = null;
    _objects = const [];
    _selected = null;
    _schema = null;
    _page = TablePage.empty;
    _integrityResult = null;
    _resetQuery();
  }

  void clearOpenError() {
    if (_openFailure == null) return;
    _openFailure = null;
    _openDetail = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Browsing
  // ---------------------------------------------------------------------------

  /// Picking an object is a request to look at its rows, so it always lands on
  /// the data tab — even when that object was already selected.
  Future<void> selectObject(DbObject object) async {
    _tabIndex = dataTabIndex;
    if (_selected?.name == object.name && _selected?.type == object.type) {
      notifyListeners();
      return;
    }
    _setBusy(true);
    try {
      await _loadObject(object);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _loadObject(DbObject object) async {
    _selected = object;
    _offset = 0;
    _sortColumn = null;
    _sortDescending = false;
    _search = '';
    _schema = await _inspector.readSchema(object);
    await _refreshPage();
  }

  Future<void> _refreshPage() async {
    final object = _selected;
    final schema = _schema;
    if (object == null || schema == null || !object.isBrowsable) {
      _page = TablePage.empty;
      return;
    }
    try {
      _page = await _inspector.fetchPage(
        object: object,
        columns: schema.columns,
        offset: _offset,
        limit: _pageSize,
        sortColumn: _sortColumn,
        descending: _sortDescending,
        search: _search,
      );
      _offset = _page.offset;
    } catch (e) {
      errorLog('SqliteViewer: page load failed: $e');
      _page = TablePage.empty;
    }
  }

  Future<void> reloadPage() async {
    _setBusy(true);
    try {
      await _refreshPage();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> goToPage(int offset) async {
    final target = offset < 0 ? 0 : offset;
    if (target == _offset) return;
    _offset = target;
    await reloadPage();
  }

  Future<void> nextPage() => goToPage(_offset + _pageSize);

  Future<void> previousPage() => goToPage(_offset - _pageSize);

  Future<void> setPageSize(int size) async {
    if (size == _pageSize) return;
    _pageSize = size;
    _offset = 0;
    await reloadPage();
  }

  Future<void> sortBy(String column) async {
    if (_sortColumn == column) {
      if (_sortDescending) {
        _sortColumn = null;
        _sortDescending = false;
      } else {
        _sortDescending = true;
      }
    } else {
      _sortColumn = column;
      _sortDescending = false;
    }
    _offset = 0;
    await reloadPage();
  }

  void setSearch(String term) {
    if (_search == term) return;
    _search = term;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _offset = 0;
      reloadPage();
    });
  }

  Future<void> runIntegrityCheck() async {
    _setBusy(true);
    try {
      _integrityResult = await _inspector.integrityCheck();
    } catch (e) {
      _integrityResult = e.toString();
    } finally {
      _setBusy(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Edit mode
  // ---------------------------------------------------------------------------

  /// Reopens the working file writable. Returns false when the file cannot be
  /// written (read-only medium, missing permission) so the caller can say why.
  Future<bool> setEditMode(bool enabled) async {
    if (!isOpen || enabled == _editMode) return true;
    if (enabled && !canEnableEditMode) return false;
    final path = _workingPath!;
    _setBusy(true);
    try {
      await _inspector.open(path, writable: enabled);
      _editMode = enabled;
      await _refreshPage();
      return true;
    } catch (e) {
      errorLog('SqliteViewer: reopen writable failed: $e');
      try {
        await _inspector.open(path);
      } catch (_) {}
      _editMode = false;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> updateCell(int rowIndex, int columnIndex, Object? value) async {
    final object = _selected;
    if (object == null || !_editMode || !object.isEditable) return false;
    final rowId = _page.rowIds.elementAtOrNull(rowIndex);
    if (rowId == null) return false;
    try {
      await _inspector.updateCell(
        table: object.name,
        column: _page.columns[columnIndex],
        rowId: rowId,
        value: value,
      );
      _hasEdits = true;
      await reloadPage();
      return true;
    } catch (e) {
      errorLog('SqliteViewer: cell update failed: $e');
      return false;
    }
  }

  Future<bool> deleteRow(int rowIndex) async {
    final object = _selected;
    if (object == null || !_editMode || !object.isEditable) return false;
    final rowId = _page.rowIds.elementAtOrNull(rowIndex);
    if (rowId == null) return false;
    try {
      await _inspector.deleteRow(table: object.name, rowId: rowId);
      _hasEdits = true;
      await reloadPage();
      return true;
    } catch (e) {
      errorLog('SqliteViewer: row delete failed: $e');
      return false;
    }
  }

  Future<bool> insertRow(Map<String, Object?> values) async {
    final object = _selected;
    if (object == null || !_editMode || !object.isEditable) return false;
    try {
      await _inspector.insertRow(table: object.name, values: values);
      _hasEdits = true;
      await reloadPage();
      return true;
    } catch (e) {
      errorLog('SqliteViewer: row insert failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Free SQL
  // ---------------------------------------------------------------------------

  SqlStatementKind get sqlKind => classifySql(_sql);

  bool get sqlNeedsEditMode => sqlKind != SqlStatementKind.read;

  void setSql(String value) {
    if (_sql == value) return;
    _sql = value;
    notifyListeners();
    _highlightDebounce?.cancel();
    _highlightDebounce = Timer(
      const Duration(milliseconds: 150),
      _rehighlightSql,
    );
  }

  Future<void> _rehighlightSql() async {
    final current = _sql;
    if (current.isEmpty) {
      _sqlTokens = const [];
      _sqlScopes = const [];
      notifyListeners();
      return;
    }
    try {
      final grammar = await SyntaxHighlighter.loadGrammar(_sqlLanguage);
      final result = await Isolate.run(
        () => TextMateEngine.tokenize(current, grammar),
      );
      if (_sql != current) return;
      _sqlTokens = result.tokens;
      _sqlScopes = result.scopes;
      notifyListeners();
    } catch (e) {
      debugLog('SqliteViewer: SQL highlight failed: $e');
    }
  }

  Future<void> runSql() async {
    if (_sql.trim().isEmpty || !isOpen) return;
    _isRunningQuery = true;
    _queryError = null;
    notifyListeners();
    try {
      _queryResult = await _inspector.runSql(_sql);
      if (_queryResult!.kind != SqlStatementKind.read) {
        _hasEdits = true;
        await _reloadAfterWrite();
      }
    } catch (e) {
      _queryResult = null;
      _queryError = _cleanSqlError(e);
    } finally {
      _isRunningQuery = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAfterWrite() async {
    _objects = await _inspector.listObjects();
    final selected = _selected;
    if (selected != null && _objects.any((o) => o.name == selected.name)) {
      _schema = await _inspector.readSchema(selected);
      await _refreshPage();
    } else {
      final first = _objects.where((o) => o.isBrowsable).firstOrNull;
      if (first != null) {
        await _loadObject(first);
      } else {
        _selected = null;
        _schema = null;
        _page = TablePage.empty;
      }
    }
  }

  String _cleanSqlError(Object error) {
    final text = error.toString();
    return text.startsWith('DatabaseException(')
        ? text
              .substring('DatabaseException('.length)
              .replaceAll(RegExp(r'\)\s*$'), '')
        : text;
  }

  void _resetQuery() {
    _sql = '';
    _queryResult = null;
    _queryError = null;
    _sqlTokens = const [];
    _sqlScopes = const [];
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Suggested file name when saving a modified snapshot back out.
  String get exportName {
    final name = _displayName ?? 'database.db';
    return name.contains('.')
        ? name.replaceFirst(RegExp(r'(\.[^.]+)$'), r'_edited$1')
        : '${name}_edited.db';
  }

  /// Checkpoints the WAL so the working file on disk holds every edit before it
  /// is copied out.
  Future<String?> prepareExport() async {
    final path = _workingPath;
    if (path == null || !await File(path).exists()) return null;
    try {
      await _inspector.runSql('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    return path;
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _highlightDebounce?.cancel();
    _searchDebounce?.cancel();
    unawaited(_inspector.close());
    super.dispose();
  }
}
