import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

class MarkdownCheckbox extends StatelessWidget {
  final bool checked;
  final Color? checkedColor;

  const MarkdownCheckbox({super.key, required this.checked, this.checkedColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = checked
        ? (checkedColor ?? AppTheme.accentTeal)
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Text(
      checked ? '\u25a3' : '\u25a1',
      style: TextStyle(fontSize: 14, color: color),
    );
  }
}
