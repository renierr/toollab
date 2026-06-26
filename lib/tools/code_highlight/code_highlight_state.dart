import 'package:flutter/material.dart';
import 'code_highlight_engine.dart';

class CodeHighlightState extends ChangeNotifier {
  bool get initialized => true;

  String? _code;
  String? get code => _code;

  String _language = 'dart';
  String get language => _language;

  String? _fileName;
  String? get fileName => _fileName;

  final List<String> supportedLanguages =
      CodeHighlightEngine.supportedLanguages;

  Future<void> initialize() async {
    // Synchronous init is already complete, keeping signature for compatibility
  }

  void setCode(String code) {
    _code = code;
    notifyListeners();
  }

  void setLanguage(String language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }

  void loadFile(String content, String fileName, String detectedLang) {
    _code = content;
    _fileName = fileName;
    _language = detectedLang;
    notifyListeners();
  }

  void clear() {
    _code = null;
    _fileName = null;
    _language = 'dart';
    notifyListeners();
  }

  String detectLanguage(String fileNameOrExtension) {
    final parts = fileNameOrExtension.split('.');
    if (parts.length < 2) return 'plain';
    final ext = parts.last.toLowerCase();
    return switch (ext) {
      'dart' => 'dart',
      'js' || 'mjs' || 'cjs' => 'javascript',
      'ts' || 'mts' || 'cts' => 'typescript',
      'py' || 'pyw' => 'python',
      'json' => 'json',
      'yaml' || 'yml' => 'yaml',
      'sql' => 'sql',
      'html' || 'htm' => 'html',
      'css' => 'css',
      'rs' => 'rust',
      'go' => 'go',
      'java' => 'java',
      'kt' || 'kts' => 'kotlin',
      'sh' || 'bash' => 'bash',
      'md' || 'markdown' => 'markdown',
      _ => 'plain',
    };
  }
}
