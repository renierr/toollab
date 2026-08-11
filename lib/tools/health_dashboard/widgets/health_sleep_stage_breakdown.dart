import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

/// One row per sleep stage: colour, name, a bar the width of its share, then
/// the duration, how often it occurred and what percentage of the night it was.
///
/// Replaces four equal-weight tiles reading "0h 15m (3 times)", which gave the
/// shortest stage the same visual weight as the longest and made the shares
/// impossible to compare at a glance.
class HealthSleepStageBreakdown extends StatelessWidget {
  final Map<String, Duration> durations;
  final Map<String, int> occurrences;

  const HealthSleepStageBreakdown({
    super.key,
    required this.durations,
    required this.occurrences,
  });

  static const _order = ['deep', 'rem', 'light', 'awake'];

  static const _colors = {
    'awake': Colors.amber,
    'rem': Colors.purple,
    'light': Colors.lightBlue,
    'deep': Colors.indigo,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final present = [
      for (final stage in _order)
        if (durations[stage] case final duration?) (stage, duration),
    ];
    if (present.isEmpty) return const SizedBox.shrink();
    final total = present.fold<int>(
      0,
      (sum, entry) => sum + entry.$2.inSeconds,
    );
    return Column(
      children: [
        for (final (stage, duration) in present)
          _StageRow(
            color: _colors[stage] ?? Colors.blueGrey,
            label: _label(l10n, stage),
            duration: duration,
            occurrences: occurrences[stage] ?? 0,
            share: total == 0 ? 0 : duration.inSeconds / total,
          ),
      ],
    );
  }

  static String _label(AppLocalizations l10n, String stage) => switch (stage) {
    'awake' => l10n.healthDashboardSleepAwake,
    'rem' => l10n.healthDashboardSleepRem,
    'light' => l10n.healthDashboardSleepLight,
    'deep' => l10n.healthDashboardSleepDeep,
    _ => stage,
  };
}

class _StageRow extends StatelessWidget {
  final Color color;
  final String label;
  final Duration duration;
  final int occurrences;
  final double share;

  const _StageRow({
    required this.color,
    required this.label,
    required this.duration,
    required this.occurrences,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.hintColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              l10n.healthDashboardSleepStageTimes(occurrences),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${(share * 100).round()} %',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
