import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../luma_well_state.dart';
import 'luma_well_help_page.dart';

class LumaWellSettingsSheet extends StatelessWidget {
  const LumaWellSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const LumaWellSettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<LumaWellState>();
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
                l10n.lumaWellSettingsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration),
                      title: Text(l10n.lumaWellHaptics),
                      subtitle: Text(l10n.lumaWellHapticsSubtitle),
                      value: state.hapticsEnabled,
                      onChanged: state.setHapticsEnabled,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: Text(l10n.lumaWellHelpTitle),
                      subtitle: Text(l10n.lumaWellHelpSubtitle),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LumaWellHelpPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.sentiment_satisfied_alt_outlined,
                      ),
                      title: Text(l10n.lumaWellEasyMode),
                      subtitle: Text(l10n.lumaWellEasyModeSubtitle),
                      value: state.easyMode,
                      onChanged: state.setEasyMode,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(l10n.lumaWellCaptureTime),
                      subtitle: Text(l10n.lumaWellCaptureTimeSubtitle),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SegmentedButton<double>(
                        segments: [
                          for (final option in const [1.0, 1.5, 2.0])
                            ButtonSegment(
                              value: option,
                              label: Text(
                                l10n.lumaWellCaptureTimeOptionSeconds(
                                  option.toStringAsFixed(1),
                                ),
                              ),
                            ),
                        ],
                        selected: {state.captureTime},
                        onSelectionChanged: (value) =>
                            state.setCaptureTime(value.first),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.all_inclusive),
                      title: Text(l10n.lumaWellUnlimitedPowers),
                      subtitle: Text(l10n.lumaWellUnlimitedPowersSubtitle),
                      value: state.unlimitedPowers,
                      onChanged: state.setUnlimitedPowers,
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
