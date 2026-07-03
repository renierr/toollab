import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../chiptune_archive.dart';
import '../chiptune_colors.dart';

/// Library of archived modules with save/sync/load/delete actions.
class ChiptuneArchivePanel extends StatelessWidget {
  final List<ArchivedModule> modules;
  final bool canSave;
  final bool syncing;
  final bool showSync;
  final String? currentId;
  final bool inScrollableParent;
  final VoidCallback onSave;
  final VoidCallback onSync;
  final ValueChanged<String> onPlay;
  final ValueChanged<String> onDownload;
  final ValueChanged<String> onDelete;

  const ChiptuneArchivePanel({
    super.key,
    required this.modules,
    required this.canSave,
    required this.syncing,
    required this.showSync,
    required this.currentId,
    this.inScrollableParent = false,
    required this.onSave,
    required this.onSync,
    required this.onPlay,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return CollapsibleSection(
      icon: Icons.library_music_outlined,
      iconColor: ChiptuneColors.accent,
      title: l10n.chipArchiveTitle(modules.length),
      actions: [
        if (showSync)
          IconButton(
            onPressed: syncing ? null : onSync,
            tooltip: l10n.chipSyncTooltip,
            icon: syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 20),
          ),
        TextButton.icon(
          onPressed: canSave ? onSave : null,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: Text(l10n.commonSave),
        ),
      ],
      child: modules.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                l10n.chipNoArchivedModules,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: inScrollableParent,
              physics: inScrollableParent
                  ? const NeverScrollableScrollPhysics()
                  : null,
              itemCount: modules.length,
              itemBuilder: (_, i) => _ArchiveItem(
                module: modules[i],
                isCurrent: modules[i].id == currentId,
                onPlay: () => onPlay(modules[i].id),
                onDownload: () => onDownload(modules[i].id),
                onDelete: () => onDelete(modules[i].id),
              ),
            ),
    );
  }
}

class _ArchiveItem extends StatelessWidget {
  final ArchivedModule module;
  final bool isCurrent;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _ArchiveItem({
    required this.module,
    required this.isCurrent,
    required this.onPlay,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: isCurrent
          ? ChiptuneColors.accent.withValues(alpha: 0.15)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            children: [
              StatusBadge(label: module.format, color: ChiptuneColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  module.title.isEmpty ? module.fileName : module.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                onPressed: onDownload,
                tooltip: l10n.chipDownloadTooltip,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.download_outlined, size: 18),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: l10n.commonDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
