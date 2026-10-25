import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sound_finder_state.dart';

/// How long each recorded file is. Shorter chunks time sounds more precisely;
/// longer ones write fewer files to the card.
class SfSleepChunkPicker extends StatelessWidget {
  const SfSleepChunkPicker({super.key});

  static const _presets = [5, 10, 15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (seconds, active) = context.select<SoundFinderState, (int, bool)>(
      (s) => (s.sleep.chunkSeconds, s.sleep.active),
    );
    final values = {..._presets, seconds}.toList()..sort();
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.sfSleepChunkLabel),
        DropdownButton<int>(
          value: seconds,
          items: [
            for (final s in values)
              DropdownMenuItem(
                value: s,
                child: Text(l10n.sfSleepChunkSeconds(s)),
              ),
          ],
          onChanged: active
              ? null
              : (value) {
                  if (value == null) return;
                  context.read<SoundFinderState>().sleep.setChunkSeconds(value);
                },
        ),
      ],
    );
  }
}
