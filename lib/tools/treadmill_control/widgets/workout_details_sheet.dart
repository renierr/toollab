import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/collapsible_section.dart';
import '../treadmill_control_colors.dart';
import '../treadmill_session.dart';
import '../workout_details_stats.dart';
import 'treadmill_metric_tile.dart';
import 'workout_details_header.dart';
import 'workout_hr_zone_bar.dart';
import 'workout_incline_chart.dart';
import 'workout_session_chart.dart';
import 'workout_splits_table.dart';

class WorkoutDetailsSheet extends StatelessWidget {
  final TreadmillSession session;
  final ScrollController? controller;

  const WorkoutDetailsSheet({
    super.key,
    required this.session,
    this.controller,
  });

  static Future<void> show(BuildContext context, TreadmillSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) =>
            WorkoutDetailsSheet(session: session, controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final stats = WorkoutDetailsStats.from(session);
    final date = DateTime.fromMillisecondsSinceEpoch(session.startTime);
    final pace = session.distance > 0
        ? session.elapsedTime / session.distance
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.treadmillDetailsTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          WorkoutDetailsHeader(
            date: DateFormat.yMMMEd(locale).add_Hm().format(date),
            distance: session.distance.toStringAsFixed(2),
            distanceLabel: 'km',
            duration: formatWorkoutDuration(session.elapsedTime),
            durationLabel: l10n.treadmillDetailsDuration,
            pace: formatPace(pace),
            paceLabel: l10n.treadmillDetailsPaceUnit,
          ),
          const SizedBox(height: 16),
          TreadmillMetricGrid(
            children: [
              TreadmillMetricTile(
                label: l10n.treadmillDetailsAvgSpeed,
                value: session.avgSpeed.toStringAsFixed(1),
                unit: 'km/h',
                icon: Icons.speed,
                color: TreadmillColors.cyanMetric,
                compact: true,
              ),
              TreadmillMetricTile(
                label: l10n.treadmillDetailsMaxSpeed,
                value: session.maxSpeed.toStringAsFixed(1),
                unit: 'km/h',
                icon: Icons.bolt,
                color: TreadmillColors.cyanMetric,
                compact: true,
              ),
              TreadmillMetricTile(
                label: l10n.treadmillDetailsAvgHr,
                value: '${session.avgHeartRate.round()}',
                unit: 'bpm',
                icon: Icons.favorite,
                color: TreadmillColors.redMetric,
                compact: true,
              ),
              TreadmillMetricTile(
                label: l10n.treadmillDetailsMaxHr,
                value: '${session.maxHeartRate.round()}',
                unit: 'bpm',
                icon: Icons.monitor_heart_outlined,
                color: TreadmillColors.redMetric,
                compact: true,
              ),
              TreadmillMetricTile(
                label: l10n.treadmillDetailsCalories,
                value: '${session.calories}',
                unit: 'kcal',
                icon: Icons.local_fire_department_outlined,
                color: TreadmillColors.amberMetric,
                compact: true,
              ),
              if (stats.minHeartRate > 0)
                TreadmillMetricTile(
                  label: l10n.treadmillDetailsMinHr,
                  value: '${stats.minHeartRate.round()}',
                  unit: 'bpm',
                  icon: Icons.arrow_downward,
                  color: TreadmillColors.greenMetric,
                  compact: true,
                ),
              if (session.steps > 0)
                TreadmillMetricTile(
                  label: l10n.treadmillDetailsSteps,
                  value: NumberFormat.decimalPattern(
                    locale,
                  ).format(session.steps),
                  icon: Icons.directions_walk,
                  color: TreadmillColors.greenMetric,
                  compact: true,
                ),
              if (stats.hasIncline) ...[
                TreadmillMetricTile(
                  label: l10n.treadmillDetailsAvgIncline,
                  value: stats.avgIncline.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.trending_up,
                  color: TreadmillColors.amberMetric,
                  compact: true,
                ),
                TreadmillMetricTile(
                  label: l10n.treadmillDetailsMaxIncline,
                  value: stats.maxIncline.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.terrain_outlined,
                  color: TreadmillColors.amberMetric,
                  compact: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (session.dataPoints.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.treadmillDetailsNoSamples,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            )
          else ...[
            CollapsibleSection(
              icon: Icons.show_chart,
              iconColor: TreadmillColors.cyanMetric,
              title: l10n.treadmillDetailsChart,
              child: WorkoutSessionChart(
                points: session.dataPoints,
                speedLabel: l10n.treadmillDetailsSpeed,
                heartRateLabel: l10n.treadmillHistoryHeartRate,
              ),
            ),
            if (stats.hasIncline)
              CollapsibleSection(
                icon: Icons.terrain_outlined,
                iconColor: TreadmillColors.amberMetric,
                title: l10n.treadmillDetailsIncline,
                child: WorkoutInclineChart(points: session.dataPoints),
              ),
            if (stats.hasZones)
              CollapsibleSection(
                icon: Icons.favorite_outline,
                iconColor: TreadmillColors.redMetric,
                title: l10n.treadmillDetailsZones,
                child: WorkoutHrZoneBar(
                  zones: stats.zones,
                  totalSeconds: stats.zoneSeconds,
                  zoneNames: [
                    l10n.treadmillDetailsZone1,
                    l10n.treadmillDetailsZone2,
                    l10n.treadmillDetailsZone3,
                    l10n.treadmillDetailsZone4,
                    l10n.treadmillDetailsZone5,
                  ],
                ),
              ),
            if (stats.splits.isNotEmpty)
              CollapsibleSection(
                icon: Icons.flag_outlined,
                iconColor: TreadmillColors.greenMetric,
                title: l10n.treadmillDetailsSplits,
                child: WorkoutSplitsTable(
                  splits: stats.splits,
                  kmHeader: l10n.treadmillDetailsSplitKm,
                  timeHeader: l10n.treadmillDetailsSplitTime,
                  paceHeader: l10n.treadmillDetailsSplitPace,
                  heartRateHeader: l10n.treadmillDetailsSplitHr,
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
