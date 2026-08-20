import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_sleep_quality.dart';
import 'package:tool_lab/helpers/health_value_format.dart';
import 'health_record_stat_item.dart';

/// Scores a night against standard sleep-study ranges and says why.
class HealthSleepQualityCard extends StatelessWidget {
  final SleepQuality quality;

  const HealthSleepQualityCard({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = switch (quality.rating) {
      SleepRating.good => AppTheme.statusGreen,
      SleepRating.fair => AppTheme.statusAmber,
      SleepRating.poor => AppTheme.statusRed,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    switch (quality.rating) {
                      SleepRating.good => l10n.healthDashboardSleepRatingGood,
                      SleepRating.fair => l10n.healthDashboardSleepRatingFair,
                      SleepRating.poor => l10n.healthDashboardSleepRatingPoor,
                    },
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.healthDashboardSleepScore(quality.score),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                HealthRecordStatItem(
                  icon: Icons.bedtime_outlined,
                  color: AppTheme.accentBlue,
                  label: l10n.healthDashboardSleepAsleep,
                  value: _duration(quality.asleep),
                ),
                HealthRecordStatItem(
                  icon: Icons.hotel_outlined,
                  color: AppTheme.accentBlue,
                  label: l10n.healthDashboardSleepTimeInBed,
                  value: _duration(quality.timeInBed),
                ),
                HealthRecordStatItem(
                  icon: Icons.percent_rounded,
                  color: color,
                  label: l10n.healthDashboardSleepEfficiency,
                  value: healthValue(quality.efficiency * 100, '%'),
                ),
                HealthRecordStatItem(
                  icon: Icons.visibility_outlined,
                  color: AppTheme.accentAmber,
                  label: l10n.healthDashboardSleepAwakenings,
                  value: '${quality.awakenings} · ${_duration(quality.awake)}',
                ),
                if (quality.deepShare case final share?)
                  HealthRecordStatItem(
                    icon: Icons.nights_stay_outlined,
                    color: Colors.indigo,
                    label: l10n.healthDashboardSleepDeep,
                    value: healthValue(share * 100, '%'),
                  ),
                if (quality.remShare case final share?)
                  HealthRecordStatItem(
                    icon: Icons.psychology_outlined,
                    color: Colors.purple,
                    label: l10n.healthDashboardSleepRem,
                    value: healthValue(share * 100, '%'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final finding in quality.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      finding == SleepFinding.allInRange
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 16,
                      color: finding == SleepFinding.allInRange
                          ? AppTheme.statusGreen
                          : theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sentence(l10n, finding),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              l10n.healthDashboardSleepQualityDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _duration(Duration duration) =>
      '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';

  static String _sentence(
    AppLocalizations l10n,
    SleepFinding finding,
  ) => switch (finding) {
    SleepFinding.allInRange => l10n.healthDashboardSleepFindingAllInRange,
    SleepFinding.durationShort => l10n.healthDashboardSleepFindingDurationShort,
    SleepFinding.durationLong => l10n.healthDashboardSleepFindingDurationLong,
    SleepFinding.efficiencyLow => l10n.healthDashboardSleepFindingEfficiencyLow,
    SleepFinding.deepLow => l10n.healthDashboardSleepFindingDeepLow,
    SleepFinding.deepHigh => l10n.healthDashboardSleepFindingDeepHigh,
    SleepFinding.remLow => l10n.healthDashboardSleepFindingRemLow,
    SleepFinding.remHigh => l10n.healthDashboardSleepFindingRemHigh,
    SleepFinding.awakeHigh => l10n.healthDashboardSleepFindingAwakeHigh,
  };
}
