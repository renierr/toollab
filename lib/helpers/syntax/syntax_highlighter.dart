import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'textmate_engine.dart';

/// Shared TextMate grammar loading, tokenization and span building.
///
/// Used by the code-highlight tool and by markdown code blocks so both render
/// with identical colors.
class SyntaxHighlighter {
  SyntaxHighlighter._();

  /// Tokenizing synchronously on the UI thread is only acceptable for small
  /// snippets — larger inputs render unhighlighted.
  static const int maxSyncChars = 20000;
  static const int maxSyncLines = 500;

  static final Map<String, Map<String, dynamic>> _grammarCache = {};

  static bool isCached(String language) =>
      language == 'plain' || _grammarCache.containsKey(language);

  static Future<Map<String, dynamic>> loadGrammar(String language) async {
    if (language == 'plain') return const {'patterns': []};
    final cached = _grammarCache[language];
    if (cached != null) return cached;
    final jsonStr = await rootBundle.loadString(
      'assets/grammars/$language.json',
    );
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    _grammarCache[language] = map;
    return map;
  }

  /// Loads the given grammars into the cache, ignoring unknown ones.
  static Future<void> preload(Iterable<String> languages) async {
    for (final language in languages.toSet()) {
      if (isCached(language)) continue;
      try {
        await loadGrammar(language);
      } catch (e) {
        debugPrint('SyntaxHighlighter: no grammar for $language ($e)');
      }
    }
  }

  /// Tokenizes [code] from the grammar cache. Returns `null` when the grammar
  /// is not cached yet, the snippet is too large, or tokenization fails.
  static IsolateResult? tokenizeSync(String code, String language) {
    if (language == 'plain') return null;
    final grammar = _grammarCache[language];
    if (grammar == null) return null;
    if (code.length > maxSyncChars) return null;
    if ('\n'.allMatches(code).length + 1 > maxSyncLines) return null;
    try {
      return TextMateEngine.tokenize(code, grammar);
    } catch (e) {
      debugPrint('SyntaxHighlighter: tokenize failed for $language ($e)');
      return null;
    }
  }

  /// Converts flat `[offset, length, scopeId]` token triplets into styled spans.
  static List<TextSpan> buildSpans(
    String code,
    List<int> tokens,
    List<String> scopes,
    ThemeData theme,
  ) {
    if (tokens.isEmpty || code.isEmpty) {
      return [TextSpan(text: code)];
    }

    final List<TextSpan> children = [];
    int lastOffset = 0;

    for (int i = 0; i + 2 < tokens.length; i += 3) {
      final start = tokens[i];
      final length = tokens[i + 1];
      final scopeId = tokens[i + 2];

      if (start > code.length) break;
      final end = (start + length).clamp(0, code.length);
      if (end <= lastOffset) continue;

      if (start > lastOffset) {
        children.add(TextSpan(text: code.substring(lastOffset, start)));
      }

      final tokenText = code.substring(start.clamp(lastOffset, end), end);
      if (scopeId < scopes.length) {
        children.add(
          TextSpan(
            text: tokenText,
            style: TextMateEngine.getScopeStyle(scopes[scopeId], theme),
          ),
        );
      } else {
        children.add(TextSpan(text: tokenText));
      }
      lastOffset = end;
    }

    if (lastOffset < code.length) {
      children.add(TextSpan(text: code.substring(lastOffset)));
    }

    return children;
  }
}
