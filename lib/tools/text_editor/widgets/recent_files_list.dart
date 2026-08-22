import 'package:flutter/material.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/tools/text_editor/text_editor_state.dart';

class RecentFilesList extends StatelessWidget {
  final TextEditorState state;
  final Future<void> Function(TextEditorRecentFile) onOpen;

  const RecentFilesList({super.key, required this.state, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recents = state.recentFiles;
    if (recents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.textEditorNoRecentFiles,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.textEditorRecentFiles,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        // Shrink-wraps inside the page's scroll view; no flex allowed there.
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recents.length,
          itemBuilder: (context, index) {
            final recent = recents[index];
            return ListTile(
              dense: true,
              leading: Icon(
                recent.isRemote
                    ? Icons.cloud_outlined
                    : Icons.insert_drive_file_outlined,
                color: AppTheme.accentTeal,
              ),
              title: Text(recent.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                recent.isRemote
                    ? '${recent.origin!.protocol.toUpperCase()} • ${recent.origin!.host}'
                    : recent.path,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: l10n.commonRemove,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => state.removeRecent(recent.path),
              ),
              onTap: () => onOpen(recent),
            );
          },
        ),
      ],
    );
  }
}
