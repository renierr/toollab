import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../chiptune_colors.dart';

/// Queue of the current multi-file selection. Highlights the playing entry
/// and lets the user jump to any track by tapping it.
class ChiptunePlaylistPanel extends StatelessWidget {
  final List<String> fileNames;
  final int currentIndex;
  final bool inScrollableParent;
  final ValueChanged<int> onPlay;

  const ChiptunePlaylistPanel({
    super.key,
    required this.fileNames,
    required this.currentIndex,
    this.inScrollableParent = false,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.queue_music_outlined,
              size: 18,
              color: ChiptuneColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.chipPlaylistTitle(fileNames.length),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: inScrollableParent,
          physics: inScrollableParent
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: fileNames.length,
          itemBuilder: (_, i) => _PlaylistItem(
            fileName: fileNames[i],
            isCurrent: i == currentIndex,
            onPlay: () => onPlay(i),
          ),
        ),
      ],
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  final String fileName;
  final bool isCurrent;
  final VoidCallback onPlay;

  const _PlaylistItem({
    required this.fileName,
    required this.isCurrent,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : '?';
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
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(
            children: [
              StatusBadge(label: ext, color: ChiptuneColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (isCurrent)
                Icon(
                  Icons.volume_up_outlined,
                  size: 18,
                  color: ChiptuneColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
