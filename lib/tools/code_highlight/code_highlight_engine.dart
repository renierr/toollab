import 'package:flutter/material.dart';

class SyntaxRule {
  final RegExp regex;
  final TextStyle Function(ThemeData theme) styleBuilder;

  SyntaxRule(
    String pattern,
    this.styleBuilder, {
    bool caseSensitive = true,
    bool multiLine = false,
  }) : regex = RegExp(
         pattern,
         caseSensitive: caseSensitive,
         multiLine: multiLine,
       );
}

class CodeHighlightEngine {
  CodeHighlightEngine._();

  static const List<String> supportedLanguages = [
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

  static final Map<String, List<SyntaxRule>> _languageRules = {
    'dart': [
      // Comments
      SyntaxRule(
        r'//.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Triple quoted strings
      SyntaxRule(
        r'r?\"\"\"[\s\S]*?\"\"\"',
        (t) => const TextStyle(color: Colors.green),
      ),
      SyntaxRule(
        r"r?'''[\s\S]*?'''",
        (t) => const TextStyle(color: Colors.green),
      ),
      // Single/Double quoted strings
      SyntaxRule(r'r?".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r"r?'.*?'", (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(void|class|import|export|as|show|hide|extends|implements|with|mixin|enum|final|const|late|var|dynamic|int|double|num|bool|String|List|Map|Set|Future|Stream|get|set|static|factory|operator|typedef|return|if|else|switch|case|default|break|continue|for|in|while|do|try|catch|finally|throw|rethrow|async|await|yield|new|this|super|is|null|true|false)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Annotations
      SyntaxRule(r'@\w+', (t) => const TextStyle(color: Colors.teal)),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
      // Functions
      SyntaxRule(
        r'\b\w+(?=\s*\()',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blueAccent,
        ),
      ),
      // Types (Capitalized identifiers)
      SyntaxRule(r'\b[A-Z]\w*\b', (t) => const TextStyle(color: Colors.teal)),
    ],
    'javascript': [
      // Comments
      SyntaxRule(
        r'//.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Strings
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r"'.*?'", (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r'`[\s\S]*?`', (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|function|if|import|in|instanceof|new|return|super|switch|this|throw|try|typeof|var|void|while|with|yield|let|package|private|protected|public|static|any|boolean|constructor|declare|get|module|require|number|readonly|set|string|symbol|type|from|of|null|true|false)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
      // Functions
      SyntaxRule(
        r'\b\w+(?=\s*\()',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blueAccent,
        ),
      ),
    ],
    'typescript': [
      // Same as JS but with specific TS types
      SyntaxRule(
        r'//.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r"'.*?'", (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r'`[\s\S]*?`', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(
        r'\b(break|case|catch|class|const|continue|debugger|default|delete|do|else|export|extends|finally|for|function|if|import|in|instanceof|new|return|super|switch|this|throw|try|typeof|var|void|while|with|yield|let|package|private|protected|public|static|any|boolean|constructor|declare|get|module|require|number|readonly|set|string|symbol|type|from|of|interface|enum|implements|keyof|namespace|as|unknown|never|void|null|true|false)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
      SyntaxRule(
        r'\b\w+(?=\s*\()',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blueAccent,
        ),
      ),
    ],
    'python': [
      // Comments
      SyntaxRule(
        r'#.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Triple quoted strings
      SyntaxRule(
        r'\"{3}[\s\S]*?\"{3}',
        (t) => const TextStyle(color: Colors.green),
      ),
      SyntaxRule(
        r"'{3}[\s\S]*?'{3}",
        (t) => const TextStyle(color: Colors.green),
      ),
      // Strings
      SyntaxRule(r'r?".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r"r?'.*?'", (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(False|None|True|and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Decorators
      SyntaxRule(r'@\w+', (t) => const TextStyle(color: Colors.teal)),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
      // Functions
      SyntaxRule(
        r'\b\w+(?=\s*\()',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blueAccent,
        ),
      ),
    ],
    'json': [
      // Keys
      SyntaxRule(
        r'\".*?\"(?=\s*:)',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.indigoAccent
              : Colors.indigo,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Strings
      SyntaxRule(r'\".*?\"', (t) => const TextStyle(color: Colors.green)),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
      // Booleans / Null
      SyntaxRule(
        r'\b(true|false|null)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
        ),
      ),
    ],
    'yaml': [
      // Comments
      SyntaxRule(
        r'#.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Keys
      SyntaxRule(
        r'[\w-]+(?=\s*:)',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.indigoAccent
              : Colors.indigo,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Strings
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r"'.*?'", (t) => const TextStyle(color: Colors.green)),
      // Booleans
      SyntaxRule(
        r'\b(true|false|null|yes|no)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
        ),
      ),
    ],
    'sql': [
      // Comments
      SyntaxRule(
        r'--.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Strings
      SyntaxRule(r"'.*?'", (t) => const TextStyle(color: Colors.green)),
      // Keywords (Case Insensitive)
      SyntaxRule(
        r'\b(SELECT|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|LIKE|IS|NULL|AS|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|ALTER|DROP|INDEX|PRIMARY|KEY|FOREIGN|REFERENCES|GROUP|BY|ORDER|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|CASE|WHEN|THEN|ELSE|END|DATABASE|SCHEMA|VIEW)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
        caseSensitive: false,
      ),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
    ],
    'html': [
      // Comments
      SyntaxRule(
        r'<!--[\s\S]*?-->',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Tag opening & closing
      SyntaxRule(
        r'</?\w+',
        (t) => const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
      SyntaxRule(
        r'/?>',
        (t) => const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Attributes
      SyntaxRule(
        r'\b[\w-]+(?=\s*=)',
        (t) => const TextStyle(color: Colors.teal),
      ),
      // Attribute values (strings)
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r"'.*?'", (t) => const TextStyle(color: Colors.green)),
    ],
    'css': [
      // Comments
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Selectors
      SyntaxRule(
        r'[\w#.+-]+(?=\s*\{)',
        (t) => const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Properties
      SyntaxRule(
        r'\b[\w-]+(?=\s*:)',
        (t) => const TextStyle(color: Colors.teal),
      ),
      // Units / Numbers
      SyntaxRule(
        r'\b\d+(px|em|rem|%|s|ms|vh|vw|deg)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
    ],
    'rust': [
      // Comments
      SyntaxRule(
        r'//.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Strings
      SyntaxRule(r'r?".*?"', (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while|macro_rules|Box|Option|Result|String|Vec)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Macros
      SyntaxRule(r'\w+!', (t) => const TextStyle(color: Colors.teal)),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
    ],
    'go': [
      // Comments
      SyntaxRule(
        r'//.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Strings
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r'`[\s\S]*?`', (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(break|default|func|interface|select|case|defer|go|map|struct|chan|else|goto|package|switch|const|fallthrough|if|range|type|continue|for|import|return|var|nil|true|false|int|string|bool|float64|error)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
    ],
    'java': [
      // Comments
      SyntaxRule(
        r'//.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Strings
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(abstract|assert|boolean|break|byte|case|catch|char|class|const|continue|default|do|double|else|enum|extends|final|finally|float|for|goto|if|implements|import|instanceof|int|interface|long|native|new|package|private|protected|public|return|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|void|volatile|while|null|true|false)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
    ],
    'kotlin': [
      // Comments
      SyntaxRule(
        r'//.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      SyntaxRule(
        r'/\*[\s\S]*?\*/',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Strings
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(val|var|fun|class|interface|object|constructor|init|override|open|sealed|data|internal|private|protected|public|import|package|if|else|when|for|while|do|break|continue|return|throw|try|catch|finally|this|super|null|true|false|as|is|in|get|set|by|out|to)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Numbers
      SyntaxRule(
        r'\b\d+(\.\d+)?\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.lightBlueAccent
              : Colors.blue,
        ),
      ),
    ],
    'bash': [
      // Comments
      SyntaxRule(
        r'#.*',
        (t) => const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      ),
      // Strings
      SyntaxRule(r'".*?"', (t) => const TextStyle(color: Colors.green)),
      SyntaxRule(r"'.*?'", (t) => const TextStyle(color: Colors.green)),
      // Keywords
      SyntaxRule(
        r'\b(if|then|else|elif|fi|case|esac|for|while|until|do|done|in|function|local|return|exit|export|alias|echo|read|set|unset)\b',
        (t) => TextStyle(
          color: t.brightness == Brightness.dark
              ? Colors.orangeAccent
              : Colors.deepOrange,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
    'markdown': [
      // Headers
      SyntaxRule(
        r'^#+ .*',
        (t) => const TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Code blocks
      SyntaxRule(r'```[\s\S]*?```', (t) => const TextStyle(color: Colors.teal)),
      // Inline code
      SyntaxRule(r'`[^`]+`', (t) => const TextStyle(color: Colors.teal)),
      // Bold
      SyntaxRule(
        r'\*\*.*?\*\*',
        (t) => const TextStyle(fontWeight: FontWeight.bold),
      ),
      // Italic
      SyntaxRule(
        r'\*.*?\*',
        (t) => const TextStyle(fontStyle: FontStyle.italic),
      ),
      // Links
      SyntaxRule(
        r'\[.*?\]\(.*?\)',
        (t) => const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    ],
  };

  static TextSpan highlight(String text, String language, ThemeData theme) {
    final rules = _languageRules[language];
    if (rules == null || rules.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontFamily: 'monospace',
        ),
      );
    }

    final List<TextSpan> children = [];
    int start = 0;
    final length = text.length;

    String accumulatedPlain = '';

    void flushPlain() {
      if (accumulatedPlain.isNotEmpty) {
        children.add(TextSpan(text: accumulatedPlain));
        accumulatedPlain = '';
      }
    }

    while (start < length) {
      Match? bestMatch;
      SyntaxRule? bestRule;

      for (final rule in rules) {
        final match = rule.regex.matchAsPrefix(text, start);
        if (match != null) {
          bestMatch = match;
          bestRule = rule;
          break;
        }
      }

      if (bestMatch != null && bestRule != null) {
        flushPlain();
        final matchedText = text.substring(start, bestMatch.end);
        children.add(
          TextSpan(text: matchedText, style: bestRule.styleBuilder(theme)),
        );
        start = bestMatch.end;
      } else {
        accumulatedPlain += text[start];
        start++;
      }
    }

    flushPlain();
    return TextSpan(
      children: children,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontFamily: 'monospace',
      ),
    );
  }
}
