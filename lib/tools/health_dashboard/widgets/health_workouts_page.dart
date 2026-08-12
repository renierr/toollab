import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import '../store/health_queries.dart';
import 'health_day_navigation.dart';
import 'health_empty_state.dart';
import 'health_metric_history.dart';
import 'health_workout_card.dart';
import 'health_workout_day_summary.dart';
import 'health_workout_trend_chart.dart';

class HealthWorkoutsPage extends StatelessWidget {
  const HealthWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();
    final day = state.selectedDay;
    final distance = state.workoutMetricValues('distanceKm');
    final calories = state.workoutMetricValues('calories');
    final hasWeek = distance.any((value) => value != null);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardWorkouts)),
      body: FutureBuilder<List<HealthRecord>>(
        future: state.workoutRecordsForDay(day),
        builder: (context, snapshot) {
          final workouts = snapshot.data ?? const [];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: HealthDayNavigation(),
              ),
              if (hasWeek) ...[
                Text(
                  l10n.healthDashboardLastSevenDays,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: HealthWorkoutTrendChart(
                      values: distance,
                      unit: 'km',
                      color: AppTheme.accentTeal,
                      overlayValues: calories,
                      overlayUnit: 'kcal',
                      overlayColor: AppTheme.accentAmber,
                      label: l10n.healthDashboardDistance,
                      overlayLabel: l10n.healthDashboardCalories,
                      endDate: state.trendWeekEnd,
                      onDayTap: (index) =>
                          state.selectDay(state.trendDayAt(index)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (workouts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: HealthEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: l10n.healthDashboardNoWorkoutsOnDay,
                    message: l10n.healthDashboardNoMetricDataInWeekHint,
                    buttonLabel: state.trendDayOffset == 0
                        ? null
                        : l10n.healthDashboardBackToToday,
                    onPressed: state.trendDayOffset == 0
                        ? null
                        : state.resetTrendDate,
                  ),
                )
              else ...[
                if (workouts.length > 1) ...[
                  HealthWorkoutDaySummary(workouts: workouts),
                  const SizedBox(height: 16),
                ],
                for (final workout in workouts) ...[
                  HealthWorkoutCard(
                    key: ValueKey(workout.id),
                    workout: workout,
                  ),
                  const SizedBox(height: 24),
                ],
              ],
              // The day above can easily be empty, so the full list is always
              // reachable here rather than only through day navigation.
              const SizedBox(height: 8),
              Text(
                l10n.healthDashboardHistory,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              HealthMetricHistory(
                metricName: l10n.healthDashboardWorkouts,
                type: HealthQueries.workoutType,
                valueKey: 'distanceKm',
                unit: 'km',
                isNap: state.isNap,
              ),
            ],
          );
        },
      ),
    );
  }
}
