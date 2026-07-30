import 'dart:convert';

/// Heuristic language detection for code snippets without an explicit
/// language (e.g. a bare markdown fence).
///
/// Deliberately conservative: a language is only reported when it clearly
/// wins, otherwise `null` (render as plain text) — a wrong guess looks worse
/// than no highlighting.
class LanguageDetector {
  LanguageDetector._();

  static const int _minScore = 3;

  static final Map<String, List<_Signal>> _signals = {
    'dart': [
      _Signal(r'\bvoid main\s*\(', 3),
      _Signal(r'\bWidget build\s*\(', 4),
      _Signal(r'@override\b', 3),
      _Signal(r'\bfinal\s+\w+\s*=', 1),
      _Signal(r'\bimport\s+.dart', 3),
    ],
    'python': [
      _Signal(r'^\s*def\s+\w+\s*\(.*\)\s*:', 3),
      _Signal(r'^\s*(from\s+[\w.]+\s+)?import\s+\w+\s*$', 2),
      _Signal(r'\belif\b', 2),
      _Signal(r'__name__|__init__|self\.', 2),
      _Signal(r'^\s*print\s*\(', 1),
    ],
    'javascript': [
      _Signal(r'\bfunction\s*\w*\s*\(', 2),
      _Signal(r'\b(const|let)\s+\w+\s*=', 2),
      _Signal(r'=>', 1),
      _Signal(r'\bconsole\.log\s*\(', 2),
      _Signal(r'\brequire\s*\(|\bmodule\.exports\b', 2),
    ],
    'typescript': [
      _Signal(r'\binterface\s+\w+\s*\{', 3),
      _Signal(r':\s*(string|number|boolean)\b', 3),
      _Signal(r'\btype\s+\w+\s*=', 2),
      _Signal(r'\bas\s+const\b|\benum\s+\w+', 2),
      _Signal(r'\bexport\s+(default\s+)?(class|function|const)\b', 1),
    ],
    'java': [
      _Signal(r'\b(public|private)\s+(static\s+)?(final\s+)?class\s+\w+', 4),
      _Signal(r'\bSystem\.out\.print', 3),
      _Signal(r'\bpublic\s+static\s+void\s+main\b', 4),
      _Signal(r'^\s*import\s+[\w.]+;', 2),
    ],
    'kotlin': [
      _Signal(r'\bfun\s+\w+\s*\(', 3),
      _Signal(r'\b(val|var)\s+\w+\s*(:|=)', 2),
      _Signal(r'\bdata class\s+\w+', 3),
      _Signal(r'\bprintln\s*\(', 1),
    ],
    'go': [
      _Signal(r'^\s*package\s+\w+\s*$', 3),
      _Signal(r'\bfunc\s+\w*\s*\(', 3),
      _Signal(r':=', 2),
      _Signal(r'\bfmt\.\w+\(', 2),
    ],
    'rust': [
      _Signal(r'\bfn\s+\w+\s*\(', 3),
      _Signal(r'\blet\s+mut\b', 3),
      _Signal(r'\b(println!|panic!|vec!)', 3),
      _Signal(r'\bimpl\s+\w+|\bpub\s+fn\b', 2),
    ],
    'sql': [
      _Signal(r'\bselect\b[\s\S]*\bfrom\b', 4),
      _Signal(r'\b(insert\s+into|update\s+\w+\s+set|delete\s+from)\b', 4),
      _Signal(r'\bcreate\s+(table|index|view)\b', 4),
      _Signal(r'\b(inner|left|right)\s+join\b|\bgroup\s+by\b', 2),
    ],
    'html': [
      _Signal(r'<!doctype\s+html', 4),
      _Signal(r'</(html|body|head|div|span|p|a|ul|li|table)>', 3),
      _Signal(r'<\w+[^>]*\s(class|id|href|src)=', 2),
    ],
    'css': [
      _Signal(r'^\s*[.#]?[\w-]+\s*\{[^}]*\}', 3),
      _Signal(r'^\s*[\w-]+\s*:\s*[^;{]+;', 2),
      _Signal(r'@(media|import|keyframes)\b', 3),
    ],
    'bash': [
      _Signal(r'^#!.*\b(sh|bash|zsh)\b', 5),
      _Signal(r'^\s*(sudo|apt|npm|git|cd|echo|export|chmod)\s+\S', 2),
      _Signal(r'\$\{?\w+\}?', 1),
      _Signal(r'\bif\s+\[\[?', 2),
    ],
    'yaml': [
      _Signal(r'^[ \t]*[\w-]+:(\s|$)', 1),
      _Signal(r'^[ \t]*-\s+[\w-]+:(\s|$)', 2),
      _Signal(r'^---\s*$', 2),
    ],
    'markdown': [
      _Signal(r'^#{1,6}\s+\S', 2),
      _Signal(r'^\s*[-*]\s+\S', 1),
      _Signal(r'\[[^\]]+\]\([^)]+\)', 2),
      _Signal(r'^>\s+\S', 1),
    ],
  };

  /// Returns the detected grammar name, or `null` when undecidable.
  static String? detect(String code) {
    final trimmed = code.trim();
    if (trimmed.length < 12) return null;

    if (_looksLikeJson(trimmed)) return 'json';

    String? best;
    int bestScore = 0;
    int runnerUpScore = 0;

    _signals.forEach((language, signals) {
      int score = 0;
      for (final signal in signals) {
        if (signal.pattern.hasMatch(code)) score += signal.weight;
      }
      if (score > bestScore) {
        runnerUpScore = bestScore;
        bestScore = score;
        best = language;
      } else if (score > runnerUpScore) {
        runnerUpScore = score;
      }
    });

    if (bestScore < _minScore) return null;
    // Ambiguous: two languages match equally well.
    if (bestScore == runnerUpScore) return null;
    return best;
  }

  static bool _looksLikeJson(String trimmed) {
    if (!(trimmed.startsWith('{') && trimmed.endsWith('}')) &&
        !(trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return false;
    }
    try {
      jsonDecode(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _Signal {
  final RegExp pattern;
  final int weight;

  _Signal(String source, this.weight)
    : pattern = RegExp(source, multiLine: true, caseSensitive: false);
}
