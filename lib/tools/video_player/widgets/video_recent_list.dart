import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/video_player/video_format.dart';

import '../video_history_entry.dart';

class VideoRecentList extends StatelessWidget {
  final List<VideoHistoryEntry> entries;
  final bool Function(VideoHistoryEntry entry) isMissing;
  final ValueChanged<VideoHistoryEntry> onPlay;
  final ValueChanged<VideoHistoryEntry> onRemove;
  final VoidCallback onClear;

  const VideoRecentList({
    super.key,
    required this.entries,
    required this.isMissing,
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
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _RecentTile(
                entry: entry,
                missing: isMissing(entry),
                onTap: () => onPlay(entry),
                onRemove: () => onRemove(entry),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  final VideoHistoryEntry entry;
  final bool missing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentTile({
    required this.entry,
    required this.missing,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = missing
        ? l10n.videoPlayerToolMissing
        : entry.finished
        ? l10n.videoPlayerToolWatched
        : l10n.videoPlayerToolProgress(
            formatVideoTime(entry.position),
            formatVideoTime(entry.duration),
          );
    return Opacity(
      opacity: missing ? 0.6 : 1,
      child: ListTile(
        leading: _Thumbnail(
          jpeg: entry.thumbnail,
          finished: entry.finished,
          missing: missing,
        ),
        title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: missing ? TextStyle(color: theme.colorScheme.error) : null,
            ),
            if (!missing) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: entry.finished ? 1 : entry.progress,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.videoPlayerToolRemoveRecent,
          onPressed: onRemove,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  static const double _width = 96;
  static const double _height = 54;

  final Uint8List? jpeg;
  final bool finished;
  final bool missing;

  const _Thumbnail({
    required this.jpeg,
    required this.finished,
    required this.missing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final jpeg = this.jpeg;
    final badge = missing
        ? Icons.broken_image_outlined
        : finished
        ? Icons.check_circle
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: _width,
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (jpeg != null && !missing)
              Image.memory(
                jpeg,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: (_width * MediaQuery.devicePixelRatioOf(context))
                    .round(),
              )
            else
              ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Icon(Icons.movie_outlined, color: colors.primary),
              ),
            if (badge != null)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      badge,
                      size: 16,
                      color: missing ? colors.error : colors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
