import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../sound_finder_state.dart';
import 'sf_gain_control.dart';
import 'sf_mic_selector.dart';

/// Input options of the live analysis modes.
class SfInputSettingsDialog extends StatelessWidget {
  const SfInputSettingsDialog({super.key});

  static const List<int> _maxLengths = [60, 300, 600, 1800, 0];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SoundFinderState>();

    return ResponsiveAlertDialog(
      title: Text(l10n.sfInputSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.micStatus == MicStatus.running)
            SfMicSelector(
              devices: state.inputDevices,
              selectedId: state.selectedDevice?.id,
              onChanged: (d) =>
                  context.read<SoundFinderState>().selectInputDevice(d),
              onRefresh: () =>
                  context.read<SoundFinderState>().refreshInputDevices(),
            ),
          const SizedBox(height: 16),
          const SfGainControl(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.sfMaxRecordLength)),
              DropdownButton<int>(
                value: _maxLengths.contains(state.maxRecordSeconds)
                    ? state.maxRecordSeconds
                    : null,
                items: [
                  for (final s in _maxLengths)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                        s == 0
                            ? l10n.sfMemoUnlimited
                            : l10n.sfMemoMinutes(s ~/ 60),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    context.read<SoundFinderState>().setMaxRecordSeconds(v);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
