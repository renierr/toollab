import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_labels.dart';
import '../sound_finder_state.dart';

class SfSleepRecordingPanel extends StatelessWidget {
  const SfSleepRecordingPanel({super.key});

  static const _recentCount = 5;
  // A countdown truncated to whole seconds would read 00:00:00 for a second.
  static const _roundUp = Duration(milliseconds: 999);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sleep = context.watch<SoundFinderState>().sleep;
    final events = sleep.events;
    final recent = events.reversed.take(_recentCount);
    final waiting = sleep.waiting;
    final recordsAt = sleep.recordsAt;
    final elapsed = sleep.elapsed;
    final endsAt = sleep.endsAt;
    String two(int v) => v.toString().padLeft(2, '0');
    String hms(Duration d) =>
        '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:'
        '${two(d.inSeconds.remainder(60))}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (waiting && recordsAt != null)
          Text(
            l10n.sfSleepGraceCountdown(
              hms(recordsAt.difference(DateTime.now()) + _roundUp),
              sleepClock(recordsAt, seconds: false),
            ),
          )
        else
          Text(l10n.sfSleepElapsed(hms(elapsed))),
        if (endsAt != null)
          Text(l10n.sfSleepEndsAt(sleepClock(endsAt, seconds: false))),
        if (!waiting) ...[
          const SizedBox(height: 4),
          Text(l10n.sfSleepSavedChunks(events.length)),
          Text(
            l10n.sfSleepPeakVsThreshold(
              sleep.lastMaxAbs.toStringAsFixed(4),
              sleep.threshold.toStringAsFixed(4),
            ),
            style: theme.textTheme.bodySmall,
          ),
          for (final e in recent)
            Text(
              '${sleepClock(e.startedAt)} – ${sleepClock(e.endedAt)} · '
              '${e.peakDb.toStringAsFixed(1)} dB',
              style: theme.textTheme.bodySmall,
            ),
        ],
        const SizedBox(height: 12),
        if (waiting) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.fiber_manual_record_outlined),
            label: Text(l10n.sfSleepGraceSkip),
            onPressed: sleep.skipGrace,
          ),
          const SizedBox(height: 8),
        ],
        ElevatedButton.icon(
          icon: const Icon(Icons.stop_outlined),
          label: Text(l10n.sfStop),
          onPressed: sleep.stop,
        ),
      ],
    );
  }
}
