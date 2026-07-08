import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sound_finder_state.dart';

/// Compact input-device picker shown while the mic is live. Lets the user route
/// analysis through an external mic (wired, USB, or Bluetooth) instead of the
/// built-in one, with a refresh to re-scan after (un)plugging a device.
class SfMicSelector extends StatelessWidget {
  const SfMicSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SoundFinderState>();

    if (state.micStatus != MicStatus.running) return const SizedBox.shrink();

    final List<InputDevice> devices = state.inputDevices;
    final Set<String> ids = devices.map((d) => d.id).toSet();
    final String? currentId = ids.contains(state.selectedDevice?.id)
        ? state.selectedDevice?.id
        : null;

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: currentId,
                hint: Text(l10n.sfMicDefault),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      l10n.sfMicDefault,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...devices.map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(d.label, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (String? id) {
                  final InputDevice? device = id == null
                      ? null
                      : devices.firstWhere((d) => d.id == id);
                  context.read<SoundFinderState>().selectInputDevice(device);
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: l10n.sfRefreshMics,
            onPressed: () =>
                context.read<SoundFinderState>().refreshInputDevices(),
          ),
        ],
      ),
    );
  }
}
