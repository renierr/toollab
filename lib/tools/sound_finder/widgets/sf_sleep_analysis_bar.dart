import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';

class SfSleepAnalysisBar extends StatelessWidget {
  const SfSleepAnalysisBar({super.key, required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = context.select<SleepSessionsState, double?>(
      (s) => s.analysisProgress(session.id),
    );
    if (progress != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sfSleepAnalyzing((progress * 100).round()),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
          ],
        ),
      );
    }
    if (session.data.isAnalyzed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.sfSleepAnalysisHint, style: theme.textTheme.bodySmall),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.sfSleepAnalyze),
            onPressed: () =>
                context.read<SleepSessionsState>().analyze(session),
          ),
        ],
      ),
    );
  }
}
