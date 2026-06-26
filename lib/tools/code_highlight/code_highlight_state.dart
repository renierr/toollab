import 'package:flutter/material.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

class CodeHighlightState extends ChangeNotifier {
  bool _initialized = false;
  bool get initialized => _initialized;

  String? _code;
  String? get code => _code;

  String _language = 'dart';
  String get language => _language;

  String? _fileName;
  String? get fileName => _fileName;

  HighlighterTheme? _lightTheme;
  HighlighterTheme? _darkTheme;

  Highlighter? _lightHighlighter;
  Highlighter? get lightHighlighter => _lightHighlighter;

  Highlighter? _darkHighlighter;
  Highlighter? get darkHighlighter => _darkHighlighter;

  final List<String> supportedLanguages = const ['dart', 'json', 'sql', 'yaml'];

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Highlighter.initialize(supportedLanguages);
      _lightTheme = await HighlighterTheme.loadLightTheme();
      _darkTheme = await HighlighterTheme.loadDarkTheme();
      _updateHighlighters();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize syntax highlighter: $e');
      // Still set initialized to true so the UI doesn't hang, but highlighters will be null
      _initialized = true;
      notifyListeners();
    }
  }

  void setCode(String code) {
    _code = code;
    notifyListeners();
  }

  void setLanguage(String language) {
    if (_language == language) return;
    _language = language;
    _updateHighlighters();
    notifyListeners();
  }

  void loadFile(String content, String fileName, String detectedLang) {
    _code = content;
    _fileName = fileName;
    _language = detectedLang;
    _updateHighlighters();
    notifyListeners();
  }

  void clear() {
    _code = null;
    _fileName = null;
    _language = 'dart';
    _updateHighlighters();
    notifyListeners();
  }

  void _updateHighlighters() {
    final themeL = _lightTheme;
    final themeD = _darkTheme;
    if (themeL == null ||
        themeD == null ||
        !supportedLanguages.contains(_language)) {
      _lightHighlighter = null;
      _darkHighlighter = null;
      return;
    }

    try {
      _lightHighlighter = Highlighter(language: _language, theme: themeL);
      _darkHighlighter = Highlighter(language: _language, theme: themeD);
    } catch (e) {
      debugPrint('Failed to create highlighter for $_language: $e');
      _lightHighlighter = null;
      _darkHighlighter = null;
    }
  }

  String detectLanguage(String fileNameOrExtension) {
    final parts = fileNameOrExtension.split('.');
    if (parts.length < 2) return 'plain';
    final ext = parts.last.toLowerCase();
    return switch (ext) {
      'dart' => 'dart',
      'json' => 'json',
      'sql' => 'sql',
      'yaml' || 'yml' => 'yaml',
      _ => 'plain',
    };
  }
}
