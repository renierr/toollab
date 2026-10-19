import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../audio/sleep_chunk_analyzer.dart';
import '../sleep_labels.dart';
import '../sleep_session_store.dart';
import '../sleep_sessions_state.dart';

/// Per-category breakdown that doubles as the filter for the timeline,
/// play-all and the chunk list.
class SfSleepCategoryFilter extends StatelessWidget {
  const SfSleepCategoryFilter({super.key, required this.session});

  final SleepSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SleepSessionsState>();
    final filter = state.filter(session.id);

    final counts = <SleepSoundCategory?, int>{};
    final activeMs = <SleepSoundCategory?, int>{};
    for (final e in session.data.events) {
      final c = e.analysis?.category;
      counts[c] = (counts[c] ?? 0) + 1;
      activeMs[c] = (activeMs[c] ?? 0) + (e.analysis?.activeMs ?? 0);
    }
    final order =
        [...SleepSoundCategory.values, null].where(counts.containsKey).toList()
          ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sfSleepSoundsTitle, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: Text(l10n.sfSleepAllSounds(session.data.events.length)),
              selected: filter.isEmpty,
              onSelected: (_) => state.clearFilter(session.id),
            ),
            for (final c in order)
              FilterChip(
                avatar: Icon(c.icon, size: 16, color: c.color),
                label: Text(
                  activeMs[c]! > 0
                      ? '${c.label(l10n)} ${counts[c]} · '
                            '${sleepDuration(Duration(milliseconds: activeMs[c]!))}'
                      : '${c.label(l10n)} ${counts[c]}',
                ),
                selected: filter.contains(c),
                showCheckmark: false,
                selectedColor: c.color.withValues(alpha: 0.25),
                onSelected: (_) => state.toggleFilter(session.id, c),
              ),
          ],
        ),
      ],
    );
  }
}
