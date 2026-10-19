import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_labels.dart';
import '../sleep_session_store.dart';
import '../sleep_player.dart';
import '../sleep_sessions_state.dart';
import 'sf_sleep_analysis_bar.dart';
import 'sf_sleep_category_filter.dart';
import 'sf_sleep_chunk_list.dart';
import 'sf_sleep_event_card.dart';
import 'sf_sleep_player_bar.dart';
import 'sf_sleep_report.dart';
import 'sf_sleep_session_actions.dart';
import 'sf_sleep_timeline.dart';

class SfSleepSessionTile extends StatelessWidget {
  const SfSleepSessionTile({super.key, required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final data = session.data;
    final locale = Localizations.localeOf(context).toString();
    final (
      progress,
      hasSelection,
    ) = context.select<SleepSessionsState, (double?, bool)>(
      (s) =>
          (s.analysisProgress(session.id), s.selectedIndex(session.id) != null),
    );
    final playingHere = context.select<SleepPlayer, bool>(
      (p) => p.sessionId == session.id,
    );

    return ExpansionTile(
      leading: Icon(
        playingHere ? Icons.graphic_eq : Icons.bedtime_outlined,
        color: playingHere ? theme.colorScheme.primary : null,
      ),
      title: Text(
        '${DateFormat.MMMEd(locale).format(data.startedAt)} · '
        '${sleepClock(data.startedAt, seconds: false)} – '
        '${sleepClock(data.endedAt, seconds: false)}',
      ),
      subtitle: Text(
        l10n.sfSleepSessionSubtitle(
          data.events.length,
          sleepDuration(data.duration),
          FormatHelper.fileSize(session.totalBytes),
        ),
      ),
      trailing: progress != null
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, value: progress),
            )
          : null,
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SfSleepReport(session: session),
        const SizedBox(height: 8),
        SfSleepAnalysisBar(session: session),
        if (data.events.any((e) => e.analysis != null)) ...[
          SfSleepCategoryFilter(session: session),
          const SizedBox(height: 8),
        ],
        SfSleepTimeline(session: session),
        const SizedBox(height: 4),
        SfSleepPlayerBar(session: session),
        if (hasSelection) SfSleepEventCard(session: session),
        const SizedBox(height: 8),
        SfSleepSessionActions(session: session),
        const SizedBox(height: 8),
        SfSleepChunkList(session: session),
      ],
    );
  }
}
