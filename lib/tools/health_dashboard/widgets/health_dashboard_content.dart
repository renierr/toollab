import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../../treadmill_control/treadmill_control_db.dart';
import '../../treadmill_control/widgets/workout_details_sheet.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import 'health_metric_card.dart';
import 'health_metric_details_page.dart';
import 'health_record_details_page.dart';
import 'health_sleep_details_page.dart';
import 'health_dashboard_trends.dart';
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
      onRefresh: () => context.read<HealthDashboardState>().collect(),
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
            spacing: 12,
            runSpacing: 12,
            children: [
              HealthMetricCard(
                icon: Icons.directions_run_rounded,
                color: AppTheme.accentTeal,
                label: l10n.healthDashboardDistance,
                value: '${state.totalDistanceKm.toStringAsFixed(1)} km',
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardDistance,
                  type: 'workout.treadmill',
                  valueKey: 'distanceKm',
                  unit: 'km',
                  color: AppTheme.accentTeal,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.local_fire_department_rounded,
                color: AppTheme.accentAmber,
                label: l10n.healthDashboardCalories,
                value: '${state.totalCalories}',
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardCalories,
                  type: 'workout.treadmill',
                  valueKey: 'calories',
                  unit: 'calories',
                  color: AppTheme.accentAmber,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.timer_outlined,
                color: AppTheme.accentBlue,
                label: l10n.healthDashboardActiveTime,
                value: _duration(state.totalDurationSeconds),
                onTap: () => _openMetric(
                  context,
                  title: l10n.healthDashboardActiveTime,
                  type: 'workout.treadmill',
                  valueKey: 'durationMinutes',
                  unit: 'min',
                  color: AppTheme.accentBlue,
                  sum: true,
                ),
              ),
              HealthMetricCard(
                icon: Icons.monitor_heart_outlined,
                color: AppTheme.accentRed,
                label: l10n.healthDashboardWorkouts,
                value: '${state.workouts.length}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HealthWorkoutsPage(),
                  ),
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
                  value: '${state.latestWeightKg!.toStringAsFixed(1)} kg',
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardWeight,
                    type: 'body.weight',
                    valueKey: 'kilograms',
                    unit: 'kg',
                    color: AppTheme.accentPurple,
                  ),
                ),
              if (state.latestRestingHeartRate != null)
                HealthMetricCard(
                  icon: Icons.favorite_outline_rounded,
                  color: AppTheme.accentRed,
                  label: l10n.healthDashboardRestingHeartRate,
                  value: '${state.latestRestingHeartRate!.round()} bpm',
                  onTap: () => _openMetric(
                    context,
                    title: l10n.healthDashboardRestingHeartRate,
                    type: 'heart.resting',
                    valueKey: 'bpm',
                    unit: 'bpm',
                    color: AppTheme.accentRed,
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
            ],
          ),
          const HealthDashboardTrends(),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.healthDashboardRecentActivity,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HealthWorkoutsPage(),
                  ),
                ),
                child: Text(l10n.healthDashboardWorkouts),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.workouts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.healthDashboardNoData),
              ),
            )
          else
            ...state.workouts
                .take(8)
                .map(
                  (record) => Card(
                    child: ListTile(
                      onTap: () async {
                        if (record.type == 'workout.treadmill') {
                          final session = await TreadmillControlDb.instance
                              .getSessionByUid(record.sourceRecordId);
                          if (session != null && context.mounted) {
                            await WorkoutDetailsSheet.show(context, session);
                          }
                        } else {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  HealthRecordDetailsPage(record: record),
                            ),
                          );
                        }
                      },
                      leading: const Icon(Icons.directions_run_rounded),
                      title: Text(
                        record.type == 'workout.treadmill'
                            ? l10n.healthDashboardTreadmillRun
                            : (record.value['title'] as String?) ??
                                  record.value['exerciseType'] as String? ??
                                  l10n.healthDashboardHealthConnectWorkout,
                      ),
                      subtitle: Text(
                        record.type == 'workout.treadmill'
                            ? '${(record.value['distanceKm'] as num).toStringAsFixed(2)} km'
                            : _duration(
                                (record.endTime - record.startTime) ~/ 1000,
                              ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _duration(
                              record.type == 'workout.treadmill'
                                  ? (record.value['durationSeconds'] as num)
                                        .round()
                                  : (record.endTime - record.startTime) ~/ 1000,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
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
