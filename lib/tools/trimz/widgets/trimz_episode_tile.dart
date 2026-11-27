import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/trimz_episode.dart';
import '../models/trimz_saved_series.dart';
import '../trimz_format.dart';
import 'trimz_poster.dart';

class TrimzEpisodeTile extends StatelessWidget {
  static const double _thumbWidth = 132;

  final TrimzEpisode episode;
  final int number;
  final bool watched;

  /// Set on the episode the viewer left off in.
  final TrimzSavedSeries? progress;
  final VoidCallback onTap;

  const TrimzEpisodeTile({
    super.key,
    required this.episode,
    required this.number,
    required this.watched,
    required this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = progress;
    final fraction = current != null && current.durationMs > 0
        ? (current.positionMs / current.durationMs).clamp(0.0, 1.0)
        : null;
    final muted = watched ? scheme.onSurfaceVariant : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: _thumbWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TrimzPoster(url: episode.posterUrl, width: _thumbWidth),
                      if (episode.duration > Duration.zero)
                        Positioned(
                          right: 4,
                          bottom: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              child: Text(
                                trimzClock(episode.duration),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (fraction != null)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 3,
                            backgroundColor: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.trimzEpisode(number),
                    style: theme.textTheme.titleSmall?.copyWith(color: muted),
                  ),
                  if (watched)
                    Text(
                      l10n.trimzWatched,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                ],
              ),
            ),
            Icon(
              watched
                  ? Icons.check_circle_outline
                  : current != null
                  ? Icons.play_circle_fill
                  : Icons.play_circle_outline,
              color: current != null ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
