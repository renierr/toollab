import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/providers/app_state.dart';
import 'package:tool_lab/theme/theme.dart';

/// One switch per sync-capable tool, so the global switch does not force a
/// megabyte-scale tool on for someone who only wanted their notes mirrored.
///
/// The list comes from the registry, so a new tool that declares a
/// `syncDelegateFactory` appears here without touching this file.
class ToolSyncSwitches extends StatelessWidget {
  const ToolSyncSwitches({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final tools = appState.syncCapableTools;
    if (tools.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.coreSyncToolsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.coreSyncToolsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final tool in tools)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(tool.icon, color: tool.accentColor),
                title: Text(tool.localizedName(l10n)),
                value: appState.isToolSyncEnabled(tool.id),
                onChanged: (value) =>
                    appState.setToolSyncEnabled(tool.id, value),
              ),
            Text(
              l10n.coreSyncToolsDisabledHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.accentAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
