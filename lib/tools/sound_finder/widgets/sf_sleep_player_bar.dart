import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_labels.dart';
import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';

/// Play-all controls; the playhead itself is drawn by the timeline.
class SfSleepPlayerBar extends StatelessWidget {
  const SfSleepPlayerBar({super.key, required this.session});

  static const _speeds = [1.0, 1.5, 2.0, 3.0];

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SleepSessionsState>();
    final queueActive =
        state.playingSessionId == session.id && state.continuous;
    final count = state.visibleIndices(session).length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!queueActive)
          FilledButton.icon(
            icon: const Icon(Icons.playlist_play),
            label: Text(l10n.sfSleepPlayAll(count)),
            onPressed: count == 0
                ? null
                : () => state.playAll(
                    session,
                    from: state.selectedIndex(session.id),
                  ),
          )
        else ...[
          IconButton(
            tooltip: l10n.sfSleepPrevChunk,
            icon: const Icon(Icons.skip_previous),
            onPressed: state.previous,
          ),
          IconButton.filled(
            tooltip: state.paused ? l10n.sfSleepResume : l10n.sfSleepPause,
            icon: Icon(state.paused ? Icons.play_arrow : Icons.pause),
            onPressed: state.togglePause,
          ),
          IconButton(
            tooltip: l10n.sfSleepNextChunk,
            icon: const Icon(Icons.skip_next),
            onPressed: state.next,
          ),
          IconButton(
            tooltip: l10n.sfSleepStopPlayback,
            icon: const Icon(Icons.stop),
            onPressed: state.stop,
          ),
          ValueListenableBuilder<DateTime?>(
            valueListenable: state.playhead,
            builder: (context, head, _) => Text(
              l10n.sfSleepPlaybackStatus(
                state.queuePosition + 1,
                state.queueLength,
                head == null ? '--:--:--' : sleepClock(head),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
        PopupMenuButton<double>(
          tooltip: l10n.sfSleepSpeed,
          initialValue: state.speed,
          onSelected: state.setSpeed,
          itemBuilder: (_) => [
            for (final s in _speeds)
              PopupMenuItem(value: s, child: Text('${_fmtSpeed(s)}×')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              '${_fmtSpeed(state.speed)}×',
              style: theme.textTheme.labelLarge,
            ),
          ),
        ),
        FilterChip(
          label: Text(l10n.sfSleepSkipQuiet),
          selected: state.skipQuiet,
          onSelected: state.setSkipQuiet,
        ),
      ],
    );
  }

  static String _fmtSpeed(double s) =>
      s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toStringAsFixed(1);
}
