import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/l10n/app_localizations.dart';
import '../chaindrop_state.dart';

/// The game's settings menu — sound and haptics, each applied immediately.
class ChainDropSettingsSheet extends StatelessWidget {
  const ChainDropSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ChainDropSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<ChainDropState>();

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.chaindropSettingsTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        state.soundEnabled
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(l10n.chaindropSound),
                      subtitle: Text(l10n.chaindropSoundSubtitle),
                      value: state.soundEnabled,
                      onChanged: state.setSoundEnabled,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.vibration,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(l10n.chaindropHaptics),
                      subtitle: Text(l10n.chaindropHapticsSubtitle),
                      value: state.hapticsEnabled,
                      onChanged: state.setHapticsEnabled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
