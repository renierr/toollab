import 'package:flutter/material.dart';
import '../code_highlight_engine.dart';

class CodeHighlightPreview extends StatelessWidget {
  final String code;
  final List<int> tokens;
  final List<String> scopes;
  final String? fileName;

  const CodeHighlightPreview({
    super.key,
    required this.code,
    required this.tokens,
    required this.scopes,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F141F) : const Color(0xFFF5F7FA);

    final List<TextSpan> children = [];
    int lastOffset = 0;

    for (int i = 0; i < tokens.length; i += 3) {
      final start = tokens[i];
      final length = tokens[i + 1];
      final scopeId = tokens[i + 2];

      if (start > code.length) break;
      final end = (start + length).clamp(0, code.length);

      if (start > lastOffset) {
        children.add(TextSpan(text: code.substring(lastOffset, start)));
      }

      final tokenText = code.substring(start, end);
      if (scopeId < scopes.length) {
        final scope = scopes[scopeId];
        final tokenStyle = TextMateEngine.getScopeStyle(scope, theme);
        children.add(TextSpan(text: tokenText, style: tokenStyle));
      } else {
        children.add(TextSpan(text: tokenText));
      }
      lastOffset = end;
    }

    if (lastOffset < code.length) {
      children.add(TextSpan(text: code.substring(lastOffset)));
    }

    final codeTextSpan = TextSpan(
      children: children,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.4,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Card(
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          color: bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: isDark
                    ? const Color(0xFF1E2530)
                    : const Color(0xFFE4E7EB),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5F56),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFBD2E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF27C93F),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      fileName ?? 'untitled.code',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text.rich(codeTextSpan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
