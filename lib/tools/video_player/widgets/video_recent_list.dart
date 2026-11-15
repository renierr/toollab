import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/video_player/video_controls.dart';

import '../video_history_entry.dart';

class VideoRecentList extends StatelessWidget {
  final List<VideoHistoryEntry> entries;
  final ValueChanged<VideoHistoryEntry> onPlay;
  final ValueChanged<VideoHistoryEntry> onRemove;
  final VoidCallback onClear;

  const VideoRecentList({
    super.key,
    required this.entries,
    required this.onPlay,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.videoPlayerToolRecent,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(l10n.videoPlayerToolClearRecent),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) => _RecentTile(
              entry: entries[index],
              onTap: () => onPlay(entries[index]),
              onRemove: () => onRemove(entries[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final VideoHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentTile({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        entry.finished ? Icons.check_circle_outline : Icons.movie_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.finished
                ? l10n.videoPlayerToolWatched
                : l10n.videoPlayerToolProgress(
                    formatVideoTime(entry.position),
                    formatVideoTime(entry.duration),
                  ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: entry.finished ? 1 : entry.progress,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.videoPlayerToolRemoveRecent,
        onPressed: onRemove,
      ),
      onTap: onTap,
    );
  }
}
