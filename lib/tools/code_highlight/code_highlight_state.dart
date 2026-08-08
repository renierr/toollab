import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/syntax/language_registry.dart';
import 'package:tool_lab/helpers/syntax/syntax_highlighter.dart';
import 'package:tool_lab/helpers/syntax/textmate_engine.dart';

class CodeHighlightState extends ChangeNotifier {
  bool get initialized => true;

  String? _code;
  String? get code => _code;

  String _language = 'dart';
  String get language => _language;

  String? _fileName;
  String? get fileName => _fileName;

  final List<String> supportedLanguages = LanguageRegistry.supportedLanguages;

  // Highlighted scopes and token triplets [offset, length, scopeId]
  List<String> _cachedScopes = [];
  List<int> _cachedTokens = [];

  List<String> get cachedScopes => _cachedScopes;
  List<int> get cachedTokens => _cachedTokens;

  bool _isHighlighting = false;
  bool get isHighlighting => _isHighlighting;

  Timer? _debounceTimer;

  Future<void> initialize() async {
    // Initial load, highlight defaults
    rehighlight();
  }

  Future<void> rehighlight() async {
    final currentCode = _code;
    final currentLang = _language;

    if (currentCode == null || currentCode.isEmpty) {
      _cachedTokens = [];
      _cachedScopes = [];
      notifyListeners();
      return;
    }

    _isHighlighting = true;
    notifyListeners();

    try {
      final grammarJson = await SyntaxHighlighter.loadGrammar(currentLang);

      final result = await Isolate.run(() {
        return TextMateEngine.tokenize(currentCode, grammarJson);
      });

      if (_code == currentCode && _language == currentLang) {
        _cachedScopes = result.scopes;
        _cachedTokens = result.tokens;
      }
    } catch (e) {
      errorLog('Highlight error for $currentLang: $e');
    } finally {
      _isHighlighting = false;
      notifyListeners();
    }
  }

  void setCode(String code) {
    if (_code == code) return;
    _code = code;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      rehighlight();
    });

    notifyListeners();
  }

  void setLanguage(String language) {
    if (_language == language) return;
    _language = language;
    rehighlight();
  }

  void loadFile(String content, String fileName, String detectedLang) {
    _code = content;
    _fileName = fileName;
    _language = detectedLang;
    rehighlight();
  }

  void clear({bool notify = true}) {
    _code = null;
    _fileName = null;
    _language = 'dart';
    _cachedTokens = [];
    _cachedScopes = [];
    if (notify) {
      notifyListeners();
    }
  }

  String detectLanguage(String fileNameOrExtension) =>
      LanguageRegistry.fromFileName(fileNameOrExtension);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
