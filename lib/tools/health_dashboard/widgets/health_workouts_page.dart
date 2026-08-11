import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import '../store/health_queries.dart';
import 'health_day_navigation.dart';
import 'health_empty_state.dart';
import 'health_metric_history.dart';
import 'health_workout_tile.dart';

class HealthWorkoutsPage extends StatelessWidget {
  const HealthWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();
    final day = state.selectedDay;

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
              else
                for (final workout in workouts)
                  HealthWorkoutTile(workout: workout),
              // The day above can easily be empty, so the full list is always
              // reachable here rather than only through day navigation.
              const SizedBox(height: 24),
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
