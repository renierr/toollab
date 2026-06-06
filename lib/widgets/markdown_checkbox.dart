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
    return SizedBox(
      width: 16,
      height: 16,
      child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: checked ? Icon(Icons.check, size: 12, color: color) : null,
          ),
        ),
      ),
    );
  }
}
