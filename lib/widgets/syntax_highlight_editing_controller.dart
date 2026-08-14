import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/syntax/syntax_highlighter.dart';

/// Monospace editing controller that paints TextMate tokens.
///
/// Tokens are pushed in by the owner rather than looked up from a provider, so
/// any tool with a tokenizer pipeline can reuse it.
class SyntaxHighlightEditingController extends TextEditingController {
  SyntaxHighlightEditingController({super.text});

  List<int> _tokens = const [];
  List<String> _scopes = const [];

  void setHighlight(List<int> tokens, List<String> scopes) {
    _tokens = tokens;
    _scopes = scopes;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final baseStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontFamily: 'monospace',
    );

    if (_tokens.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    return TextSpan(
      children: SyntaxHighlighter.buildSpans(text, _tokens, _scopes, theme),
      style: baseStyle,
    );
  }
}
