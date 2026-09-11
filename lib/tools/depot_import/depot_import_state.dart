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

  Future<void> addFiles(List<({String path, String name})> files) async {
    if (files.isEmpty) return;
    _isImporting = true;
    _importDone = 0;
    _importTotal = files.length;
    _error = null;
    notifyListeners();

    for (final file in files) {
      try {
        final text = await _extractText(file.path);
        _statements.add(
          DepotStatementParser.parse(
            id: 'stmt-${_idCounter++}',
            fileName: file.name,
            rawText: text,
          ),
        );
      } catch (e) {
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

    _isImporting = false;
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
    notifyListeners();
  }

  void clear() {
    if (_statements.isEmpty && _error == null) return;
    _statements.clear();
    _error = null;
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
    notifyListeners();
  }

  String buildCsv() {
    final rows = exportable.map((s) => s.activity!).toList();
    debugLog('DepotImport: exporting ${rows.length} activities');
    return ParqetCsv.build(rows);
  }
}
