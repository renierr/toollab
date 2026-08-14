import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import '../health_value_format.dart';
import '../store/health_queries.dart';
import 'health_metric_card.dart';
import 'health_metric_details_page.dart';
import 'health_sleep_details_page.dart';
import 'health_dashboard_trends.dart';
import 'health_day_navigation.dart';
import 'health_all_data_page.dart';
import 'health_workouts_page.dart';

class HealthDashboardContent extends StatelessWidget {
  const HealthDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => context.read<HealthDashboardState>().refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text(
            l10n.healthDashboardHeadline,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.healthDashboardSubtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HealthMetricCard(
                icon: Icons.directions_run_rounded,
                color: AppTheme.accentTeal,
                label: l10n.healthDashboardDistanceAllTime,
                value: healthValue(state.allTimeDistanceKm, 'km'),
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardDistance,
                  type: HealthQueries.workoutType,
                  valueKey: 'distanceKm',
                  unit: 'km',
                  color: AppTheme.accentTeal,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.directions_walk_rounded,
                color: AppTheme.accentGreen,
                label: l10n.healthDashboardStepsAllTime,
                value: '${state.allTimeSteps}',
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardStepsToday,
                  type: 'activity.steps',
                  valueKey: 'count',
                  unit: 'steps',
                  color: AppTheme.accentGreen,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.timer_outlined,
                color: AppTheme.accentBlue,
                label: l10n.healthDashboardActiveTimeAllTime,
                value: _duration(state.allTimeDurationSeconds),
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardActiveTime,
                  type: HealthQueries.workoutType,
                  valueKey: 'durationMinutes',
                  unit: 'min',
                  color: AppTheme.accentBlue,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.local_fire_department_rounded,
                color: AppTheme.accentAmber,
                label: l10n.healthDashboardCaloriesAllTime,
                value: '${state.allTimeCalories}',
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardCalories,
                  type: HealthQueries.workoutType,
                  valueKey: 'calories',
                  unit: 'calories',
                  color: AppTheme.accentAmber,
                  sum: true,
                ),
              ),
              if (state.latestSleepMinutes != null)
                HealthMetricCard(
                  icon: Icons.bedtime_outlined,
                  color: AppTheme.accentBlue,
                  label: l10n.healthDashboardLastSleep,
                  value: _duration(state.latestSleepMinutes! * 60),
                  onTap: () => _openSleepDetails(context, state),
                ),
              if (state.latestHeartRate != null)
                HealthMetricCard(
                  icon: Icons.favorite_rounded,
                  color: AppTheme.accentRed,
                  label: l10n.healthDashboardLatestHeartRate,
                  value: healthValue(state.latestHeartRate!, 'bpm'),
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardHeartRate,
                    type: 'heart.rate',
                    valueKey: 'value',
                    unit: 'bpm',
                    color: AppTheme.accentRed,
                  ),
                ),
              if (state.latestRestingHeartRate != null)
                HealthMetricCard(
                  icon: Icons.favorite_outline_rounded,
                  color: AppTheme.accentRed,
                  label: l10n.healthDashboardLatestRestingHeartRate,
                  value: healthValue(state.latestRestingHeartRate!, 'bpm'),
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardRestingHeartRate,
                    type: 'heart.resting',
                    valueKey: 'bpm',
                    unit: 'bpm',
                    color: AppTheme.accentRed,
                  ),
                ),
              if (state.latestHrv != null)
                HealthMetricCard(
                  icon: Icons.monitor_heart_rounded,
                  color: AppTheme.accentPurple,
                  label: l10n.healthDashboardHrv,
                  value: healthValue(state.latestHrv!, 'ms'),
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardHrv,
                    type: 'health.heart_rate_variability_rmssd',
                    valueKey: 'rmssdMs',
                    unit: 'ms',
                    color: AppTheme.accentPurple,
                  ),
                ),
              if (state.todaySteps > 0)
                HealthMetricCard(
                  icon: Icons.directions_walk_rounded,
                  color: AppTheme.accentGreen,
                  label: l10n.healthDashboardStepsToday,
                  value: '${state.todaySteps}',
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardStepsToday,
                    type: 'activity.steps',
                    valueKey: 'count',
                    unit: 'steps',
                    color: AppTheme.accentGreen,
                    sum: true,
                  ),
                ),
              if (state.latestWeightKg != null)
                HealthMetricCard(
                  icon: Icons.monitor_weight_outlined,
                  color: AppTheme.accentPurple,
                  label: l10n.healthDashboardWeight,
                  value: healthValue(state.latestWeightKg!, 'kg'),
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardWeight,
                    type: 'body.weight',
                    valueKey: 'kilograms',
                    unit: 'kg',
                    color: AppTheme.accentPurple,
                  ),
                ),
              if (state.latestBodyFat != null)
                HealthMetricCard(
                  icon: Icons.pie_chart_outline_rounded,
                  color: AppTheme.accentAmber,
                  label: l10n.healthDashboardLatestBodyFat,
                  value: healthValue(state.latestBodyFat!, '%'),
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardBodyFat,
                    type: 'health.body_fat_percentage',
                    valueKey: 'percent',
                    unit: '%',
                    color: AppTheme.accentAmber,
                  ),
                ),
              if (state.latestSpO2 != null)
                HealthMetricCard(
                  icon: Icons.percent_rounded,
                  color: AppTheme.accentBlue,
                  label: l10n.healthDashboardLatestOxygenSaturation,
                  value: healthValue(state.latestSpO2!, '%'),
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardOxygenSaturation,
                    type: 'health.oxygen_saturation',
                    valueKey: 'percent',
                    unit: '%',
                    color: AppTheme.accentBlue,
                  ),
                ),
              if (state.latestRespiratoryRate != null)
                HealthMetricCard(
                  icon: Icons.air_rounded,
                  color: AppTheme.accentTeal,
                  label: l10n.healthDashboardLatestRespiratoryRate,
                  value: healthValue(state.latestRespiratoryRate!, 'rpm'),
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardRespiratoryRate,
                    type: 'health.respiratory_rate',
                    valueKey: 'respiratoryRate',
                    unit: 'rpm',
                    color: AppTheme.accentTeal,
                  ),
                ),
              HealthMetricCard(
                icon: Icons.monitor_heart_outlined,
                color: AppTheme.accentRed,
                label: l10n.healthDashboardWorkoutsAllTime,
                value: '${state.allTimeWorkouts}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HealthWorkoutsPage(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.healthDashboardLastSevenDays,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const HealthDayNavigation(),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HealthMetricCard(
                icon: Icons.directions_run_rounded,
                color: AppTheme.accentTeal,
                label: l10n.healthDashboardDistanceLastSevenDays,
                value: healthValue(state.selectedWeekDistanceKm, 'km'),
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardDistance,
                  type: HealthQueries.workoutType,
                  valueKey: 'distanceKm',
                  unit: 'km',
                  color: AppTheme.accentTeal,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.directions_walk_rounded,
                color: AppTheme.accentGreen,
                label: l10n.healthDashboardStepsLastSevenDays,
                value: '${state.selectedWeekSteps}',
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardStepsToday,
                  type: 'activity.steps',
                  valueKey: 'count',
                  unit: 'steps',
                  color: AppTheme.accentGreen,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.timer_outlined,
                color: AppTheme.accentBlue,
                label: l10n.healthDashboardActiveTimeLastSevenDays,
                value: _duration(state.selectedWeekDurationSeconds),
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardActiveTime,
                  type: HealthQueries.workoutType,
                  valueKey: 'durationMinutes',
                  unit: 'min',
                  color: AppTheme.accentBlue,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.local_fire_department_rounded,
                color: AppTheme.accentAmber,
                label: l10n.healthDashboardCaloriesLastSevenDays,
                value: '${state.selectedWeekCalories}',
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardCalories,
                  type: HealthQueries.workoutType,
                  valueKey: 'calories',
                  unit: 'calories',
                  color: AppTheme.accentAmber,
                  sum: true,
                ),
              ),
            ],
          ),
          const HealthDashboardTrends(),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.health_and_safety_outlined),
            label: Text(l10n.healthDashboardAllData),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HealthAllDataPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _duration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  void _openMetric(
    BuildContext context, {
    required String title,
    required String type,
    required String valueKey,
    required String unit,
    required Color color,
    bool sum = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthMetricDetailsPage(
          title: title,
          type: type,
          valueKey: valueKey,
          unit: unit,
          color: color,
          sum: sum,
        ),
      ),
    );
  }

  void _openSleepDetails(BuildContext context, HealthDashboardState state) {
    final record = state
        .recordsOfType('sleep.session', preferredOnly: true)
        .where((record) => !state.isNap(record))
        .fold<HealthRecord?>(null, (latest, candidate) {
          if (latest == null || candidate.endTime > latest.endTime) {
            return candidate;
          }
          return latest;
        });
    if (record == null) return;
    state.selectDay(DateTime.fromMillisecondsSinceEpoch(record.endTime));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthSleepDetailsPage(record: record),
      ),
    );
  }
}
