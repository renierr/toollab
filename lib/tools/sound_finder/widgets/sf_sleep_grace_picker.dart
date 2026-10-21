import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_labels.dart';
import '../sound_finder_state.dart';

class SfSleepGracePicker extends StatelessWidget {
  const SfSleepGracePicker({super.key});

  static const _presets = [0, 1, 2, 5, 10, 15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = context.select<SoundFinderState, int>(
      (s) => s.sleep.graceMinutes,
    );
    final values = {..._presets, minutes}.toList()..sort();

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.sfSleepGraceLabel),
        DropdownButton<int>(
          value: minutes,
          items: [
            for (final m in values)
              DropdownMenuItem(
                value: m,
                child: Text(
                  m == 0 ? l10n.sfSleepGraceOff : sleepTimerLabel(l10n, m),
                ),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            context.read<SoundFinderState>().sleep.setGraceMinutes(v);
          },
        ),
      ],
    );
  }
}
