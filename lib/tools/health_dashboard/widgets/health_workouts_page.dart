import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../../treadmill_control/treadmill_control_db.dart';
import '../../treadmill_control/widgets/workout_details_sheet.dart';
import '../health_dashboard_state.dart';
import '../health_record.dart';
import 'health_record_details_page.dart';

class HealthWorkoutsPage extends StatelessWidget {
  const HealthWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workouts = context.watch<HealthDashboardState>().workouts;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardWorkouts)),
      body: workouts.isEmpty
          ? Center(child: Text(l10n.healthDashboardNoData))
          : ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                final date = DateTime.fromMillisecondsSinceEpoch(
                  workout.startTime,
                );
                return ListTile(
                  leading: const Icon(Icons.directions_run_rounded),
                  title: Text(
                    workout.type == 'workout.treadmill'
                        ? l10n.healthDashboardTreadmillRun
                        : (workout.value['title'] as String?) ??
                              workout.value['exerciseType'] as String? ??
                              l10n.healthDashboardHealthConnectWorkout,
                  ),
                  subtitle: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(date)} · '
                    '${_workoutSummary(workout)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    if (workout.type == 'workout.treadmill') {
                      final session = await TreadmillControlDb.instance
                          .getSessionByUid(workout.sourceRecordId);
                      if (session != null && context.mounted) {
                        await WorkoutDetailsSheet.show(context, session);
                      }
                    } else if (context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HealthRecordDetailsPage(record: workout),
                        ),
                      );
                    }
                  },
                );
              },
            ),
    );
  }

  String _workoutSummary(HealthRecord workout) {
    final distance = workout.value['distanceKm'] as num?;
    if (distance != null) return '${distance.toStringAsFixed(2)} km';
    final duration = Duration(
      milliseconds: workout.endTime - workout.startTime,
    );
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
}
