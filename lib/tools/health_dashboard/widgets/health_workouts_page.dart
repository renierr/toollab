import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../../treadmill_control/treadmill_control_db.dart';
import '../../treadmill_control/widgets/workout_details_sheet.dart';
import '../health_dashboard_state.dart';

class HealthWorkoutsPage extends StatelessWidget {
  const HealthWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workouts = context.watch<HealthDashboardState>().treadmillWorkouts;
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
                  title: Text(l10n.healthDashboardTreadmillRun),
                  subtitle: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(date)} · '
                    '${(workout.value['distanceKm'] as num).toStringAsFixed(2)} km',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final session = await TreadmillControlDb.instance
                        .getSessionByUid(workout.sourceRecordId);
                    if (session != null && context.mounted) {
                      await WorkoutDetailsSheet.show(context, session);
                    }
                  },
                );
              },
            ),
    );
  }
}
