import 'package:flutter/material.dart';
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
  final VoidCallback onSave;
  final VoidCallback onSync;
  final ValueChanged<String> onPlay;
  final ValueChanged<String> onDelete;

  const ChiptuneArchivePanel({
    super.key,
    required this.modules,
    required this.canSave,
    required this.syncing,
    required this.showSync,
    required this.currentId,
    required this.onSave,
    required this.onSync,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 18,
              color: ChiptuneColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              'Archive (${modules.length})',
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            if (showSync)
              IconButton(
                onPressed: syncing ? null : onSync,
                tooltip: 'Sync',
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
              label: const Text('Save'),
            ),
          ],
        ),
        if (modules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              'No archived modules',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...modules.map(
            (m) => _ArchiveItem(
              module: m,
              isCurrent: m.id == currentId,
              onPlay: () => onPlay(m.id),
              onDelete: () => onDelete(m.id),
            ),
          ),
      ],
    );
  }
}

class _ArchiveItem extends StatelessWidget {
  final ArchivedModule module;
  final bool isCurrent;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _ArchiveItem({
    required this.module,
    required this.isCurrent,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                onPressed: onDelete,
                tooltip: 'Delete',
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
