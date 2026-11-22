import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../models/x_watched_video.dart';
import '../x_feed_state.dart';
import '../x_video_history.dart';
import 'x_history_group_header.dart';
import 'x_history_tile.dart';

/// Watched videos grouped by when they were last played.
class XHistoryView extends StatefulWidget {
  const XHistoryView({super.key});

  @override
  State<XHistoryView> createState() => _XHistoryViewState();
}

class _XHistoryViewState extends State<XHistoryView> {
  @override
  void initState() {
    super.initState();
    context.read<XFeedState>().history.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.read<XFeedState>().history;
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final entries = history.entries;
        if (entries == null) {
          // Released while the tab stayed alive, e.g. after the tool closed.
          history.ensureLoaded();
          return const Center(child: CircularProgressIndicator());
        }
        if (entries.isEmpty) return const _EmptyHistory();
        final rows = <Object>[
          for (final group in XVideoHistory.group(entries)) ...[
            group,
            ...group.entries,
          ],
        ];
        return ReadableScrollPadding(
          padding: const EdgeInsets.only(bottom: 24),
          builder: (context, padding) => ListView.builder(
            padding: padding,
            itemCount: rows.length,
            itemBuilder: (context, i) => switch (rows[i]) {
              final XHistoryGroup group => XHistoryGroupHeader(group: group),
              final XWatchedVideo entry => XHistoryTile(entry: entry),
              _ => const SizedBox.shrink(),
            },
          ),
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).xFeedHistoryEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
