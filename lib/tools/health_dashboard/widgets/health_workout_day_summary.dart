import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import 'package:tool_lab/widgets/workout/workout_details_stats.dart';
import '../health_record.dart';
import '../health_record_values.dart';
import 'package:tool_lab/helpers/health_value_format.dart';
import 'health_record_stat_item.dart';

/// What a day of workouts adds up to, shown above the sessions themselves.
///
/// Only useful with more than one session, so the page leaves it out for a
/// single workout - the card below would repeat the same numbers.
class HealthWorkoutDaySummary extends StatelessWidget {
  final List<HealthRecord> workouts;

  const HealthWorkoutDaySummary({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = workouts.fold<int>(
      0,
      (sum, workout) => sum + (workout.endTime - workout.startTime) ~/ 1000,
    );
    final distance = _total('distanceKm');
    final calories = _total('calories');
    final steps = _total('count');
    final heartRates = [
      for (final workout in workouts)
        if (workout.value['averageHeartRate'] case final num average) average,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.healthDashboardWorkoutDayTotals,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                HealthRecordStatItem(
                  icon: Icons.fitness_center_rounded,
                  color: AppTheme.accentGreen,
                  label: l10n.healthDashboardWorkoutSessions,
                  value: '${workouts.length}',
                ),
                HealthRecordStatItem(
                  icon: Icons.timer_outlined,
                  color: AppTheme.accentBlue,
                  label: l10n.healthDashboardActiveTime,
                  value: formatWorkoutDuration(seconds),
                ),
                if (distance > 0)
                  HealthRecordStatItem(
                    icon: Icons.straighten_rounded,
                    color: AppTheme.accentTeal,
                    label: l10n.healthDashboardDistance,
                    value: healthValue(distance, 'km'),
                  ),
                if (calories > 0)
                  HealthRecordStatItem(
                    icon: Icons.local_fire_department_rounded,
                    color: AppTheme.accentAmber,
                    label: l10n.healthDashboardCalories,
                    value: healthValue(calories, 'kcal'),
                  ),
                if (heartRates.isNotEmpty)
                  HealthRecordStatItem(
                    icon: Icons.favorite_outline_rounded,
                    color: AppTheme.accentRed,
                    label: l10n.healthDashboardAvgHeartRate,
                    value: healthValue(
                      heartRates.reduce((a, b) => a + b) / heartRates.length,
                      'bpm',
                    ),
                  ),
                if (steps > 0)
                  HealthRecordStatItem(
                    icon: Icons.directions_walk_rounded,
                    color: AppTheme.accentGreen,
                    label: l10n.steps,
                    value: healthValue(steps, 'count'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _total(String key) => workouts.fold<double>(
    0,
    (sum, workout) => sum + (healthRecordValue(workout, key) ?? 0),
  );
}
