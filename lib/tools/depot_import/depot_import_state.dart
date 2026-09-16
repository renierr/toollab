import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/pdf_engine_helper.dart';

import 'models/depot_activity.dart';
import 'parqet_csv.dart';
import 'parsing/statement_parser.dart';

class DepotImportState extends ChangeNotifier {
  final List<ParsedStatement> _statements = [];
  bool _isImporting = false;
  int _importDone = 0;
  int _importTotal = 0;
  String? _error;
  int _idCounter = 0;
  int _importGeneration = 0;

  List<ParsedStatement> get statements => List.unmodifiable(_statements);
  bool get isImporting => _isImporting;
  int get importDone => _importDone;
  int get importTotal => _importTotal;
  String? get error => _error;
  bool get isEmpty => _statements.isEmpty;

  int get issueCount => _statements.where((s) => s.issues.isNotEmpty).length;

  List<ParsedStatement> get exportable =>
      _statements.where((s) => s.selected && s.isExportable).toList()
        ..sort((a, b) => a.activity!.date!.compareTo(b.activity!.date!));

  /// Groups imports of the same document twice: same type, ISIN, booking day
  /// and gross amount. Only selected statements count, so deselecting one
  /// copy resolves the warning.
  static String duplicateKey(DepotActivity a) {
    final d = a.date;
    final dateKey = d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${a.type.name}|${a.isin}|$dateKey|${a.amount.toStringAsFixed(2)}';
  }

  static Set<String> findDuplicateIds(List<ParsedStatement> statements) {
    final groups = <String, List<String>>{};
    for (final s in statements) {
      final a = s.activity;
      if (!s.selected || a == null || a.isin.isEmpty || a.date == null) {
        continue;
      }
      groups.putIfAbsent(duplicateKey(a), () => []).add(s.id);
    }
    return {
      for (final ids in groups.values)
        if (ids.length > 1) ...ids,
    };
  }

  void _refreshDuplicates() {
    final dupIds = findDuplicateIds(_statements);
    for (var i = 0; i < _statements.length; i++) {
      final s = _statements[i];
      final has = s.issues.contains(DepotParseIssue.duplicate);
      final want = dupIds.contains(s.id);
      if (has == want) continue;
      final issues = s.issues.toList();
      if (want) {
        issues.add(DepotParseIssue.duplicate);
      } else {
        issues.remove(DepotParseIssue.duplicate);
      }
      _statements[i] = s.copyWith(issues: issues);
    }
  }

  Future<void> addFiles(List<({String path, String name})> files) async {
    if (files.isEmpty) return;
    final generation = ++_importGeneration;
    _isImporting = true;
    _importDone = 0;
    _importTotal = files.length;
    _error = null;
    notifyListeners();

    for (final file in files) {
      try {
        final text = await _extractText(file.path);
        if (generation != _importGeneration) return;
        _statements.add(
          DepotStatementParser.parse(
            id: 'stmt-${_idCounter++}',
            fileName: file.name,
            rawText: text,
          ),
        );
      } catch (e) {
        if (generation != _importGeneration) return;
        errorLog('DepotImport: failed to read ${file.name}: $e');
        _statements.add(
          ParsedStatement(
            id: 'stmt-${_idCounter++}',
            fileName: file.name,
            bank: DepotBank.unknown,
            activity: null,
            issues: const [DepotParseIssue.noText],
            rawText: '',
          ),
        );
      }
      _importDone++;
      notifyListeners();
    }

    if (generation != _importGeneration) return;
    _isImporting = false;
    _refreshDuplicates();
    notifyListeners();
  }

  static Future<String> _extractText(String path) async {
    PdfDocument? doc;
    try {
      doc = await PdfEngineHelper.openPdf(path);
      final buffer = StringBuffer();
      for (final page in doc.pages) {
        final pageText = await page.loadText();
        if (pageText != null) buffer.writeln(pageText.fullText);
      }
      return buffer.toString();
    } finally {
      await doc?.dispose();
    }
  }

  void remove(String id) {
    _statements.removeWhere((s) => s.id == id);
    _refreshDuplicates();
    notifyListeners();
  }

  void clear() {
    if (_statements.isEmpty && _error == null && !_isImporting) return;
    _importGeneration++;
    _statements.clear();
    _error = null;
    _isImporting = false;
    _importDone = 0;
    _importTotal = 0;
    notifyListeners();
  }

  void toggleSelected(String id) {
    _replace(id, (s) => s.copyWith(selected: !s.selected));
  }

  void updateActivity(String id, DepotActivity activity) {
    _replace(
      id,
      (s) => s.copyWith(
        activity: activity,
        issues: DepotStatementParser.revalidate(activity),
        edited: true,
      ),
    );
  }

  void _replace(String id, ParsedStatement Function(ParsedStatement) update) {
    final index = _statements.indexWhere((s) => s.id == id);
    if (index < 0) return;
    _statements[index] = update(_statements[index]);
    _refreshDuplicates();
    notifyListeners();
  }

  String buildCsv() {
    final rows = exportable.map((s) => s.activity!).toList();
    debugLog('DepotImport: exporting ${rows.length} activities');
    return ParqetCsv.build(rows);
  }
}
