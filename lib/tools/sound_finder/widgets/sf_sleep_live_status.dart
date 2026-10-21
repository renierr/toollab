import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../sleep_labels.dart';
import '../sound_finder_state.dart';

class SfSleepLiveStatus extends StatelessWidget {
  const SfSleepLiveStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();
    final sleep = state.sleep;
    final db = state.smoothDb.toStringAsFixed(1);
    final last = sleep.lastEvent;
    final recording = sleep.active && !sleep.waiting;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic_outlined,
            color: recording
                ? AppTheme.statusRed
                : sleep.waiting
                ? AppTheme.statusAmber
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recording
                  ? l10n.sfSleepLiveActive(
                      db,
                      last == null ? l10n.sfSleepNone : sleepClock(last),
                    )
                  : l10n.sfSleepLiveIdle(db),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
