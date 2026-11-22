import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../x_format.dart';
import '../x_video_history.dart';

class XHistoryGroupHeader extends StatelessWidget {
  final XHistoryGroup group;

  const XHistoryGroupHeader({super.key, required this.group});

  static String title(AppLocalizations l10n, XHistoryPeriod period) =>
      switch (period) {
        XHistoryPeriod.today => l10n.xFeedHistoryToday,
        XHistoryPeriod.week => l10n.xFeedHistoryWeek,
        XHistoryPeriod.month => l10n.xFeedHistoryMonth,
        XHistoryPeriod.year => l10n.xFeedHistoryYear,
        XHistoryPeriod.older => l10n.xFeedHistoryOlder,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final top = group.topAuthor;
    final meta = [
      l10n.xFeedHistoryVideos(group.entries.length),
      l10n.xFeedHistoryPlays(group.plays),
      l10n.xFeedHistoryWatchedTotal(XFormat.clock(group.watched)),
      if (top != null) l10n.xFeedHistoryTopAuthor(top),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title(l10n, group.period),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
