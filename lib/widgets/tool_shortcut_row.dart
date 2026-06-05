import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';

class ToolShortcutRow extends StatelessWidget {
  final ToolModel tool;
  final bool hasDrawerIcon;
  final VoidCallback onPinPressed;
  final ValueChanged<bool> onDrawerIconChanged;

  const ToolShortcutRow({
    super.key,
    required this.tool,
    required this.hasDrawerIcon,
    required this.onPinPressed,
    required this.onDrawerIconChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tool.accentColor.withValues(alpha: 0.15),
                  foregroundColor: tool.accentColor,
                  child: Icon(tool.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tool.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Home Screen Shortcut'),
              subtitle: const Text('Add shortcut to your home launcher screen'),
              trailing: OutlinedButton.icon(
                onPressed: onPinPressed,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tool.accentColor,
                  side: BorderSide(
                    color: tool.accentColor.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('App Drawer Icon'),
              subtitle: const Text('Show separate launcher icon in App Drawer'),
              value: hasDrawerIcon,
              onChanged: onDrawerIconChanged,
            ),
          ],
        ),
      ),
    );
  }
}
