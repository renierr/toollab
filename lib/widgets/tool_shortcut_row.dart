import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class ToolShortcutRow extends StatelessWidget {
  final ToolModel tool;
  final bool hasShortcut;
  final bool hasDrawerIcon;
  final bool enabled;
  final VoidCallback onPinPressed;
  final ValueChanged<bool> onDrawerIconChanged;

  const ToolShortcutRow({
    super.key,
    required this.tool,
    required this.hasShortcut,
    required this.hasDrawerIcon,
    required this.onPinPressed,
    required this.onDrawerIconChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: tool.accentColor.withValues(alpha: 0.15),
            foregroundColor: tool.accentColor,
            child: Icon(tool.icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tool.localizedName(l10n),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  tool.localizedDescription(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: enabled ? onPinPressed : null,
            tooltip: hasShortcut
                ? l10n.coreShortcutsPinnedTooltip
                : l10n.coreShortcutsPinTooltip,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              hasShortcut
                  ? Icons.check_circle
                  : Icons.add_to_home_screen_outlined,
              color: hasShortcut ? tool.accentColor : null,
            ),
          ),
          Tooltip(
            message: l10n.coreShortcutsDrawerTooltip,
            child: Switch.adaptive(
              value: hasDrawerIcon,
              onChanged: enabled ? onDrawerIconChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
