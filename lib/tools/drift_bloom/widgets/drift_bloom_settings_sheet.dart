import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../drift_bloom_state.dart';
import 'drift_bloom_help_page.dart';

class DriftBloomSettingsSheet extends StatelessWidget {
  const DriftBloomSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const DriftBloomSettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<DriftBloomState>();
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.driftBloomSettingsTitle,
                style: Theme.of(context).textTheme.titleMedium,
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
                      ),
                      title: Text(l10n.driftBloomSound),
                      subtitle: Text(l10n.driftBloomSoundSubtitle),
                      value: state.soundEnabled,
                      onChanged: state.setSoundEnabled,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration),
                      title: Text(l10n.driftBloomHaptics),
                      subtitle: Text(l10n.driftBloomHapticsSubtitle),
                      value: state.hapticsEnabled,
                      onChanged: state.setHapticsEnabled,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(l10n.driftBloomHelpTitle),
                      subtitle: Text(l10n.driftBloomHelpSubtitle),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DriftBloomHelpPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.sentiment_satisfied_alt_outlined,
                      ),
                      title: Text(l10n.driftBloomEasyMode),
                      subtitle: Text(l10n.driftBloomEasyModeSubtitle),
                      value: state.easyMode,
                      onChanged: state.setEasyMode,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(l10n.driftBloomRingLife),
                      subtitle: Text(l10n.driftBloomRingLifeSubtitle),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SegmentedButton<double>(
                        segments: [
                          for (final option in const [8.0, 10.0, 12.0])
                            ButtonSegment(
                              value: option,
                              label: Text(
                                l10n.driftBloomRingLifeOptionSeconds(
                                  option.toStringAsFixed(0),
                                ),
                              ),
                            ),
                        ],
                        selected: {state.ringLife},
                        onSelectionChanged: (value) =>
                            state.setRingLife(value.first),
                      ),
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
