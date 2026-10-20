import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sound_finder_state.dart';
import 'sf_sleep_live_status.dart';
import 'sf_sleep_recording_panel.dart';
import 'sf_sleep_sessions_page.dart';
import 'sf_sleep_setup_panel.dart';

class SfSleepView extends StatelessWidget {
  const SfSleepView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (active, micUnavailable, finishing) = context
        .select<SoundFinderState, (bool, bool, bool)>(
          (s) => (s.sleep.active, s.sleep.micUnavailable, s.sleep.finishing),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.sfSleepRecorderTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.sfSleepRecorderIntro, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (micUnavailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.sfSleepMicUnavailable,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SfSleepLiveStatus(),
        if (finishing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.sfSleepFinishing,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        active ? const SfSleepRecordingPanel() : const SfSleepSetupPanel(),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.list_outlined),
          label: Text(l10n.sfSleepViewSessions),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SfSleepSessionsPage()),
          ),
        ),
      ],
    );
  }
}
