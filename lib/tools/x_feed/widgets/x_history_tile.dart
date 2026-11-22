import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/x_watched_video.dart';
import '../x_feed_state.dart';
import '../x_format.dart';
import '../x_media_actions.dart';

/// Tap plays the video again; the close button removes the entry.
class XHistoryTile extends StatelessWidget {
  final XWatchedVideo entry;

  const XHistoryTile({super.key, required this.entry});

  void _remove(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = context.read<XFeedState>().history;
    unawaited(history.remove(entry));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.xFeedHistoryRemoved),
          action: SnackBarAction(
            label: l10n.xFeedUndo,
            onPressed: () => unawaited(history.restore(entry)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final meta = [
      XFormat.relativeTime(entry.lastWatchedAt, l10n, locale),
      l10n.xFeedHistoryWatched(XFormat.clock(entry.watched)),
      if (entry.playCount > 1) l10n.xFeedHistoryPlays(entry.playCount),
    ].join(' · ');
    return ListTile(
      onTap: () => XMediaActions.openWatched(context, entry),
      leading: _Thumbnail(entry: entry),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: entry.authorName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: '  @${entry.authorScreenName}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.text.isNotEmpty)
            Text(entry.text, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.xFeedHistoryRemove,
        onPressed: () => _remove(context),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  static const double _width = 96;
  static const double _height = 54;

  final XWatchedVideo entry;

  const _Thumbnail({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final placeholder = Icon(
      Icons.movie_outlined,
      color: scheme.onSurfaceVariant,
    );
    final badge = entry.isGif
        ? AppLocalizations.of(context).xFeedGifBadge
        : entry.duration > Duration.zero
        ? XFormat.clock(entry.duration)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: _width,
        height: _height,
        color: scheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              entry.previewUrl,
              fit: BoxFit.cover,
              cacheWidth: (_width * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) => placeholder,
            ),
            if (badge != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.scrim.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
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
