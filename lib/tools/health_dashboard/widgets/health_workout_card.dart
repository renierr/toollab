import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../../treadmill_control/treadmill_control_db.dart';
import 'package:tool_lab/widgets/workout/workout_details_sheet.dart';
import 'package:tool_lab/widgets/workout/workout_details_stats.dart';
import '../health_dashboard_state.dart';
import '../health_record.dart';
import '../health_record_values.dart';
import 'package:tool_lab/helpers/health_value_format.dart';
import '../store/health_metric_catalog.dart';
import 'health_record_details_page.dart';
import 'health_record_stat_item.dart';
import 'health_session_metric_stats.dart';
import 'health_session_overlay.dart';
import 'health_session_timeline_section.dart';
import 'health_source_badge.dart';

/// Everything stored about one workout: its summary figures, its laps, and the
/// dense curves recorded while it ran.
///
/// The curves are read per workout the same way a night reads its overlays, so a
/// session from any point in history shows them, not only one in the loaded week.
class HealthWorkoutCard extends StatefulWidget {
  final HealthRecord workout;

  const HealthWorkoutCard({super.key, required this.workout});

  @override
  State<HealthWorkoutCard> createState() => _HealthWorkoutCardState();
}

class _HealthWorkoutCardState extends State<HealthWorkoutCard> {
  /// Curves a workout can carry, in the order they are shown. Units and colours
  /// live here; the labels come from the build, which is where l10n is reachable.
  static const _curves = [
    (HealthMetrics.heartRate, 'bpm', AppTheme.accentRed),
    (HealthMetrics.speed, 'km/h', AppTheme.accentTeal),
    (HealthMetrics.cadence, 'rpm', AppTheme.accentBlue),
    (HealthMetrics.power, 'W', AppTheme.accentAmber),
  ];

  Map<String, List<HealthTimedValue>> _samples = const {};

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  @override
  void didUpdateWidget(HealthWorkoutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workout.id != widget.workout.id) _loadSamples();
  }

  Future<void> _loadSamples() async {
    final state = context.read<HealthDashboardState>();
    final loaded = <String, List<HealthTimedValue>>{};
    for (final (metric, _, _) in _curves) {
      loaded[metric] = await state.metricSamplesDuring(widget.workout, metric);
    }
    if (mounted) setState(() => _samples = loaded);
  }

  List<HealthSessionOverlay> _overlayList(AppLocalizations l10n) => [
    for (final (metric, unit, color) in _curves)
      HealthSessionOverlay(
        key: metric,
        label: _curveLabel(metric, l10n),
        unit: unit,
        color: color,
        samples: _samples[metric] ?? const [],
      ),
  ];

  static String _curveLabel(String metric, AppLocalizations l10n) =>
      switch (metric) {
        HealthMetrics.speed => l10n.healthDashboardSpeed,
        HealthMetrics.cadence => l10n.healthDashboardCadence,
        HealthMetrics.power => l10n.healthDashboardPower,
        _ => l10n.healthDashboardHeartRate,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workout = widget.workout;
    final overlays = _overlayList(l10n);
    final start = DateTime.fromMillisecondsSinceEpoch(workout.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(workout.endTime);
    final seconds = (workout.endTime - workout.startTime) ~/ 1000;
    final time = MaterialLocalizations.of(context);
    final laps = _laps(workout);
    final drawable = overlays.where((overlay) => overlay.isDrawable).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openDetails(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        _activityIcon(workout),
                        color: AppTheme.accentTeal,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(workout, l10n),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${time.formatMediumDate(start)} · '
                              '${time.formatTimeOfDay(TimeOfDay.fromDateTime(start))} - '
                              '${time.formatTimeOfDay(TimeOfDay.fromDateTime(end))}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: _stats(context, l10n, seconds),
                    ),
                    if (laps.length > 1) ...[
                      const Divider(height: 28),
                      _Laps(laps: laps),
                    ],
                    const SizedBox(height: 12),
                    HealthSourceBadge(packageName: workout.sourceName),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (drawable.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.healthDashboardDuringWorkout,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          HealthSessionTimelineSection(
            startTime: workout.startTime,
            endTime: workout.endTime,
            overlays: overlays,
          ),
          for (final overlay in drawable) ...[
            const SizedBox(height: 20),
            HealthSessionMetricStats(
              overlay: overlay,
              averageLabel: l10n.healthDashboardAverage,
              minimumLabel: l10n.healthDashboardMinimum,
              maximumLabel: l10n.healthDashboardMaximum,
            ),
          ],
        ],
      ],
    );
  }

  List<Widget> _stats(
    BuildContext context,
    AppLocalizations l10n,
    int seconds,
  ) {
    final value = widget.workout.value;
    final distance = (value['distanceKm'] as num?)?.toDouble() ?? 0;
    return [
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
      if (distance > 0)
        HealthRecordStatItem(
          icon: Icons.timeline_rounded,
          color: AppTheme.accentTeal,
          label: l10n.healthDashboardPace,
          value: '${formatPace(seconds / distance)} /km',
        ),
      if (value['calories'] case final num calories when calories > 0)
        HealthRecordStatItem(
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.accentAmber,
          label: l10n.healthDashboardCalories,
          value: healthValue(calories, 'kcal'),
        ),
      if (value['averageHeartRate'] case final num average)
        HealthRecordStatItem(
          icon: Icons.favorite_outline_rounded,
          color: AppTheme.accentRed,
          label: l10n.healthDashboardAvgHeartRate,
          value: healthValue(average, 'bpm'),
        ),
      if (value['maximumHeartRate'] case final num maximum)
        HealthRecordStatItem(
          icon: Icons.monitor_heart_outlined,
          color: AppTheme.accentRed,
          label: l10n.healthDashboardMaxHeartRate,
          value: healthValue(maximum, 'bpm'),
        ),
      if (value['averageSpeedKmh'] case final num average)
        HealthRecordStatItem(
          icon: Icons.speed_rounded,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardAvgSpeed,
          value: healthValue(average, 'km/h'),
        ),
      if (value['maximumSpeedKmh'] case final num maximum)
        HealthRecordStatItem(
          icon: Icons.bolt_rounded,
          color: AppTheme.accentBlue,
          label: l10n.healthDashboardMaxSpeed,
          value: healthValue(maximum, 'km/h'),
        ),
      if (value['count'] case final num steps when steps > 0)
        HealthRecordStatItem(
          icon: Icons.directions_walk_rounded,
          color: AppTheme.accentGreen,
          label: l10n.steps,
          value: healthValue(steps, 'count'),
        ),
    ];
  }

  Future<void> _openDetails(BuildContext context) async {
    final workout = widget.workout;
    if (workout.type == 'workout.treadmill') {
      final session = await TreadmillControlDb.instance.getSessionByUid(
        workout.sourceRecordId,
      );
      if (session != null && context.mounted) {
        await WorkoutDetailsSheet.show(context, session);
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthRecordDetailsPage(record: workout),
      ),
    );
  }

  static List<({int start, int end, double? distanceKm})> _laps(
    HealthRecord workout,
  ) => [
    for (final lap in (workout.value['laps'] as List? ?? const []))
      if (lap is Map && lap['startTime'] is num && lap['endTime'] is num)
        (
          start: (lap['startTime'] as num).toInt(),
          end: (lap['endTime'] as num).toInt(),
          distanceKm: (lap['distanceKm'] as num?)?.toDouble(),
        ),
  ];

  static String _title(HealthRecord workout, AppLocalizations l10n) {
    if (workout.type == 'workout.treadmill') {
      return l10n.healthDashboardTreadmillRun;
    }
    final raw =
        (workout.value['title'] as String?) ??
        (workout.value['exerciseType'] as String?);
    if (raw == null || raw.isEmpty) {
      return l10n.healthDashboardHealthConnectWorkout;
    }
    final words = raw.replaceAll('_', ' ').split(' ');
    return [
      for (final word in words)
        if (word.isNotEmpty) word[0].toUpperCase() + word.substring(1),
    ].join(' ');
  }

  static IconData _activityIcon(HealthRecord workout) {
    final activity = (workout.value['exerciseType'] as String? ?? '')
        .toLowerCase();
    if (activity.contains('bik') || activity.contains('cycl')) {
      return Icons.directions_bike_rounded;
    }
    if (activity.contains('swim')) return Icons.pool_rounded;
    if (activity.contains('walk') || activity.contains('hik')) {
      return Icons.directions_walk_rounded;
    }
    if (activity.contains('strength') || activity.contains('weight')) {
      return Icons.fitness_center_rounded;
    }
    if (activity.contains('row')) return Icons.rowing_rounded;
    if (activity.contains('yoga')) return Icons.self_improvement_rounded;
    return Icons.directions_run_rounded;
  }
}

/// Laps as the writer recorded them, with the pace each one was run at.
class _Laps extends StatelessWidget {
  final List<({int start, int end, double? distanceKm})> laps;

  const _Laps({required this.laps});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.healthDashboardLaps, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        for (var index = 0; index < laps.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.healthDashboardLap(index + 1),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  _lapText(laps[index], l10n),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _lapText(
    ({int start, int end, double? distanceKm}) lap,
    AppLocalizations l10n,
  ) {
    final seconds = (lap.end - lap.start) ~/ 1000;
    final duration = formatWorkoutDuration(seconds);
    final distance = lap.distanceKm;
    if (distance == null || distance <= 0) return duration;
    return '${healthValue(distance, 'km')} · $duration · '
        '${formatPace(seconds / distance)} /km';
  }
}
