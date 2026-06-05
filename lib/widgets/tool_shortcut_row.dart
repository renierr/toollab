import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';

class ToolShortcutRow extends StatelessWidget {
  final ToolModel tool;
  final bool isPinned;
  final ValueChanged<bool> onChanged;

  const ToolShortcutRow({
    super.key,
    required this.tool,
    required this.isPinned,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        secondary: CircleAvatar(
          backgroundColor: tool.accentColor.withValues(alpha: 0.15),
          foregroundColor: tool.accentColor,
          child: Icon(tool.icon),
        ),
        title: Text(
          tool.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          tool.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        value: isPinned,
        onChanged: onChanged,
      ),
    );
  }
}
