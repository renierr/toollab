import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'code_highlight_engine.dart';

class CodeHighlightState extends ChangeNotifier {
  bool get initialized => true;

  String? _code;
  String? get code => _code;

  String _language = 'dart';
  String get language => _language;

  String? _fileName;
  String? get fileName => _fileName;

  final List<String> supportedLanguages = [
    'dart',
    'javascript',
    'typescript',
    'python',
    'json',
    'yaml',
    'sql',
    'html',
    'css',
    'rust',
    'go',
    'java',
    'kotlin',
    'bash',
    'markdown',
  ];

  // Grammar cache to avoid reading files repeatedly
  final Map<String, Map<String, dynamic>> _grammarCache = {};

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

  Future<Map<String, dynamic>> _loadGrammar(String language) async {
    if (language == 'plain') {
      return {'patterns': []};
    }
    if (_grammarCache.containsKey(language)) {
      return _grammarCache[language]!;
    }
    final jsonStr = await rootBundle.loadString(
      'assets/grammars/$language.json',
    );
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    _grammarCache[language] = map;
    return map;
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
      final grammarJson = await _loadGrammar(currentLang);

      final result = await Isolate.run(() {
        return TextMateEngine.tokenize(currentCode, grammarJson);
      });

      if (_code == currentCode && _language == currentLang) {
        _cachedScopes = result.scopes;
        _cachedTokens = result.tokens;
      }
    } catch (e) {
      debugPrint('Highlight error for $currentLang: $e');
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
