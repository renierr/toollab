import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../../treadmill_control/treadmill_control_db.dart';
import '../../treadmill_control/widgets/workout_details_sheet.dart';

import '../health_dashboard_state.dart';
import 'health_metric_card.dart';

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
          FilledButton.icon(
            onPressed: state.isCollecting
                ? null
                : () => context
                      .read<HealthDashboardState>()
                      .connectHealthConnect(),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: Text(l10n.healthDashboardConnectHealthConnect),
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
              ),
              HealthMetricCard(
                icon: Icons.local_fire_department_rounded,
                color: AppTheme.accentAmber,
                label: l10n.healthDashboardCalories,
                value: '${state.totalCalories}',
              ),
              HealthMetricCard(
                icon: Icons.timer_outlined,
                color: AppTheme.accentBlue,
                label: l10n.healthDashboardActiveTime,
                value: _duration(state.totalDurationSeconds),
              ),
              HealthMetricCard(
                icon: Icons.monitor_heart_outlined,
                color: AppTheme.accentRed,
                label: l10n.healthDashboardWorkouts,
                value: '${state.treadmillWorkouts.length}',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            l10n.healthDashboardRecentActivity,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (state.treadmillWorkouts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.healthDashboardNoData),
              ),
            )
          else
            ...state.treadmillWorkouts
                .take(8)
                .map(
                  (record) => Card(
                    child: ListTile(
                      onTap: () async {
                        final session = await TreadmillControlDb.instance
                            .getSessionByUid(record.sourceRecordId);
                        if (session != null && context.mounted) {
                          await WorkoutDetailsSheet.show(context, session);
                        }
                      },
                      leading: const Icon(Icons.directions_run_rounded),
                      title: Text(l10n.healthDashboardTreadmillRun),
                      subtitle: Text(
                        '${(record.value['distanceKm'] as num).toStringAsFixed(2)} km',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _duration(
                              (record.value['durationSeconds'] as num).round(),
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
}
