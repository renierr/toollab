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
    final state = context.read<SleepSessionsState>();
    final filter = context.select<SleepSessionsState, Set<SleepSoundCategory?>>(
      (s) => s.filter(session.id),
    );

    final counts = <SleepSoundCategory?, int>{};
    void bump(SleepSoundCategory? c) => counts[c] = (counts[c] ?? 0) + 1;
    for (final e in session.data.events) {
      final a = e.analysis;
      if (a == null) {
        bump(null);
      } else if (a.subEvents.isEmpty) {
        bump(a.category);
      } else {
        for (final c in {for (final s in a.subEvents) s.category}) {
          bump(c);
        }
      }
    }
    final durations = session.data.soundDurations;
    final activeMs = <SleepSoundCategory?, int>{
      for (final entry in durations.entries)
        entry.key: entry.value.inMilliseconds,
    };
    final order =
        [...SleepSoundCategory.values, null]
            .where((c) => counts.containsKey(c) || activeMs.containsKey(c))
            .toList()
          ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

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
              _CategoryChip(
                category: c,
                count: counts[c] ?? 0,
                durationMs: activeMs[c] ?? 0,
                selected: filter.contains(c),
                onTap: () => state.toggleFilter(session.id, c),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.count,
    required this.durationMs,
    required this.selected,
    required this.onTap,
  });

  final SleepSoundCategory? category;
  final int count;
  final int durationMs;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = category.label(l10n);
    return FilterChip(
      avatar: Icon(category.icon, size: 16, color: category.color),
      label: Text(
        durationMs > 0
            ? '$label $count · '
                  '${sleepDuration(Duration(milliseconds: durationMs))}'
            : '$label $count',
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: category.color.withValues(alpha: 0.25),
      onSelected: (_) => onTap(),
    );
  }
}
