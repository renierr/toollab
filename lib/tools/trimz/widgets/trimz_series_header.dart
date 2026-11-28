import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';

import '../models/trimz_saved_series.dart';
import '../models/trimz_series.dart';
import '../models/trimz_series_detail.dart';
import '../trimz_format.dart';
import 'trimz_poster.dart';

/// Poster, facts and the play buttons; the poster sits beside the text when
/// there is room.
class TrimzSeriesHeader extends StatelessWidget {
  final TrimzSeries series;
  final TrimzSeriesDetail? detail;
  final TrimzSavedSeries? saved;

  /// Null until the episodes are loaded.
  final void Function(int index)? onPlay;
  final VoidCallback onToggleList;

  /// Marks the whole series watched or unwatched; null until episodes load.
  final void Function(bool watched)? onSetWatched;

  const TrimzSeriesHeader({
    super.key,
    required this.series,
    required this.detail,
    required this.saved,
    required this.onPlay,
    required this.onToggleList,
    required this.onSetWatched,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final info = detail;
    final episodes = info?.episodes.length ?? series.episodeCount;
    final views = info?.views ?? series.views;
    final summary = info?.summary ?? series.summary;
    final owner = info?.ownerName ?? series.ownerName;
    final resuming = saved != null && saved!.watched && episodes > 0;
    final resumeIndex = resuming ? saved!.nextIndex(episodes) : 0;
    final onList = saved?.onList ?? false;
    final watchedAll = saved?.watchedAll(episodes) ?? false;
    final play = onPlay;
    final setWatched = onSetWatched;

    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info?.title ?? series.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (owner != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.trimzBy(owner),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (episodes > 0)
              _Fact(
                icon: Icons.video_library_outlined,
                label: l10n.trimzEpisodeCount(episodes),
              ),
            if (info != null && info.runtime > Duration.zero)
              _Fact(
                icon: Icons.schedule,
                label: trimzRuntime(l10n, info.runtime),
              ),
            if (views > 0)
              _Fact(
                icon: Icons.visibility_outlined,
                label: l10n.trimzViews(trimzCompact(views, locale)),
              ),
          ],
        ),
        if (summary != null) ...[
          const SizedBox(height: 12),
          Text(summary, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: play == null ? null : () => play(resumeIndex),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                resuming
                    ? l10n.trimzContinueEpisode(resumeIndex + 1)
                    : l10n.trimzPlay,
              ),
            ),
            if (resuming && resumeIndex > 0)
              OutlinedButton.icon(
                onPressed: play == null ? null : () => play(0),
                icon: const Icon(Icons.replay),
                label: Text(l10n.trimzStartOver),
              ),
            OutlinedButton.icon(
              onPressed: onToggleList,
              icon: Icon(onList ? Icons.bookmark : Icons.bookmark_border),
              label: Text(onList ? l10n.trimzOnList : l10n.trimzAddToList),
            ),
            OutlinedButton.icon(
              onPressed: setWatched == null
                  ? null
                  : () => setWatched(!watchedAll),
              icon: Icon(watchedAll ? Icons.remove_done : Icons.done_all),
              label: Text(
                watchedAll ? l10n.trimzMarkUnwatched : l10n.trimzMarkWatched,
              ),
            ),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.canSplit;
        final posterWidth = split
            ? constraints.maxWidth * 0.42
            : constraints.maxWidth;
        final poster = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: TrimzPoster(
              url: series.posterUrl ?? info?.thumbnailUrl,
              width: posterWidth,
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: split
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: posterWidth - 16, child: poster),
                    const SizedBox(width: 20),
                    Expanded(child: facts),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [poster, const SizedBox(height: 16), facts],
                ),
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Fact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
