import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';

class SfSleepKeepDaysPicker extends StatelessWidget {
  const SfSleepKeepDaysPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = context.select<SleepSessionsState, int>((s) => s.keepDays);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.sfSleepKeepAudio),
            DropdownButton<int>(
              value: days,
              items: [
                for (final d in SleepSessionStore.keepDaysOptions)
                  DropdownMenuItem(
                    value: d,
                    child: Text(
                      d == 0
                          ? l10n.sfSleepKeepForever
                          : l10n.sfSleepKeepDays(d),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  context.read<SleepSessionsState>().setKeepDays(v);
                }
              },
            ),
          ],
        ),
        Text(l10n.sfSleepKeepHint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
