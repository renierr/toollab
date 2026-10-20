import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_labels.dart';
import '../sound_finder_state.dart';
import 'sf_sleep_duration_dialog.dart';

class SfSleepDurationPicker extends StatelessWidget {
  const SfSleepDurationPicker({super.key});

  static const _presets = [60, 120, 240, 360, 420, 480, 540, 600, 720];
  static const _custom = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = context.select<SoundFinderState, int>(
      (s) => s.sleep.durationMinutes,
    );
    final values = {..._presets, minutes}.toList()..sort();

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.sfSleepDurationLabel),
        DropdownButton<int>(
          value: minutes,
          items: [
            for (final m in values)
              DropdownMenuItem(value: m, child: Text(sleepTimerLabel(l10n, m))),
            DropdownMenuItem(
              value: _custom,
              child: Text(l10n.sfSleepTimerCustom),
            ),
          ],
          onChanged: (v) async {
            if (v == null) return;
            final sleep = context.read<SoundFinderState>().sleep;
            if (v != _custom) {
              sleep.setDurationMinutes(v);
              return;
            }
            final picked = await SfSleepDurationDialog.show(
              context,
              initial: minutes,
            );
            if (picked != null) sleep.setDurationMinutes(picked);
          },
        ),
      ],
    );
  }
}
