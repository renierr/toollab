import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/collapsible_section.dart';

import 'package:tool_lab/widgets/workout/workout_colors.dart';
import 'package:tool_lab/widgets/workout/workout_session.dart';
import 'package:tool_lab/widgets/metric_tile.dart';
import 'package:tool_lab/widgets/workout/workout_details_header.dart';
import 'package:tool_lab/widgets/workout/workout_hr_zone_bar.dart';
import 'package:tool_lab/widgets/workout/workout_incline_chart.dart';
import 'package:tool_lab/widgets/workout/workout_session_chart.dart';
import 'package:tool_lab/widgets/workout/workout_splits_table.dart';
import 'package:tool_lab/widgets/workout/workout_details_stats.dart';
import '../health_record.dart';
import 'package:tool_lab/helpers/health_value_format.dart';
import 'health_source_badge.dart';

class HealthTreadmillDetailsPage extends StatelessWidget {
  final HealthRecord record;

  const HealthTreadmillDetailsPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final points = _points(record.value);
    final session = _session(points);
    final stats = WorkoutDetailsStats.from(session);
    final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final locale = Localizations.localeOf(context).toString();
    final pace = session.distance > 0
        ? session.elapsedTime / session.distance
        : 0.0;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.treadmillDetailsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WorkoutDetailsHeader(
            date: DateFormat.yMMMEd(locale).add_Hm().format(date),
            distance: healthNumber(session.distance, 'km'),
            distanceLabel: 'km',
            duration: formatWorkoutDuration(session.elapsedTime),
            durationLabel: l10n.treadmillDetailsDuration,
            pace: formatPace(pace),
            paceLabel: l10n.treadmillDetailsPaceUnit,
          ),
          const SizedBox(height: 16),
          MetricGrid(
            children: [
              MetricTile(
                label: l10n.treadmillDetailsAvgSpeed,
                value: healthNumber(session.avgSpeed, 'km/h'),
                unit: 'km/h',
                icon: Icons.speed,
                color: TreadmillColors.cyanMetric,
                compact: true,
              ),
              MetricTile(
                label: l10n.treadmillDetailsMaxSpeed,
                value: healthNumber(session.maxSpeed, 'km/h'),
                unit: 'km/h',
                icon: Icons.bolt,
                color: TreadmillColors.cyanMetric,
                compact: true,
              ),
              MetricTile(
                label: l10n.treadmillDetailsAvgHr,
                value: session.avgHeartRate.round().toString(),
                unit: 'bpm',
                icon: Icons.favorite,
                color: TreadmillColors.redMetric,
                compact: true,
              ),
              MetricTile(
                label: l10n.treadmillDetailsMaxHr,
                value: session.maxHeartRate.round().toString(),
                unit: 'bpm',
                icon: Icons.monitor_heart_outlined,
                color: TreadmillColors.redMetric,
                compact: true,
              ),
              MetricTile(
                label: l10n.treadmillDetailsCalories,
                value: session.calories.toString(),
                unit: 'kcal',
                icon: Icons.local_fire_department_outlined,
                color: TreadmillColors.amberMetric,
                compact: true,
              ),
              if (stats.minHeartRate > 0)
                MetricTile(
                  label: l10n.treadmillDetailsMinHr,
                  value: stats.minHeartRate.round().toString(),
                  unit: 'bpm',
                  icon: Icons.arrow_downward,
                  color: TreadmillColors.greenMetric,
                  compact: true,
                ),
              if (session.steps > 0)
                MetricTile(
                  label: l10n.treadmillDetailsSteps,
                  value: session.steps.toString(),
                  icon: Icons.directions_walk,
                  color: TreadmillColors.greenMetric,
                  compact: true,
                ),
              if (stats.hasIncline) ...[
                MetricTile(
                  label: l10n.treadmillDetailsAvgIncline,
                  value: healthNumber(stats.avgIncline, '%'),
                  unit: '%',
                  icon: Icons.trending_up,
                  color: TreadmillColors.amberMetric,
                  compact: true,
                ),
                MetricTile(
                  label: l10n.treadmillDetailsMaxIncline,
                  value: healthNumber(stats.maxIncline, '%'),
                  unit: '%',
                  icon: Icons.terrain_outlined,
                  color: TreadmillColors.amberMetric,
                  compact: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          HealthSourceBadge(packageName: record.sourceName),
          if (points.length >= 2) ...[
            const SizedBox(height: 24),
            CollapsibleSection(
              icon: Icons.show_chart,
              iconColor: TreadmillColors.cyanMetric,
              title: l10n.treadmillDetailsChart,
              child: WorkoutSessionChart(
                points: points,
                speedLabel: l10n.treadmillDetailsSpeed,
                heartRateLabel: l10n.hrLabel,
              ),
            ),
            if (stats.hasIncline)
              CollapsibleSection(
                icon: Icons.terrain_outlined,
                iconColor: TreadmillColors.amberMetric,
                title: l10n.treadmillDetailsIncline,
                child: WorkoutInclineChart(points: points),
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
            CollapsibleSection(
              icon: Icons.multiline_chart_rounded,
              iconColor: AppTheme.accentTeal,
              title: l10n.healthDashboardTrends,
              child: _WorkoutProgressChart(points: points),
            ),
          ],
          const SizedBox(height: 24),
          CollapsibleSection(
            icon: Icons.data_object_rounded,
            title: l10n.healthDashboardData,
            initiallyExpanded: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(record.value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<WorkoutDataPoint> _points(Map<String, dynamic> value) =>
      (value['dataPoints'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (point) =>
                WorkoutDataPoint.fromMap(Map<String, dynamic>.from(point)),
          )
          .toList();

  double _number(Map<String, dynamic> value, String key) =>
      (value[key] as num?)?.toDouble() ?? 0;

  TreadmillSession _session(List<WorkoutDataPoint> points) => TreadmillSession(
    uid: record.sourceRecordId,
    startTime: record.startTime,
    endTime: record.endTime,
    avgSpeed: _number(record.value, 'averageSpeedKmh'),
    maxSpeed: _number(record.value, 'maxSpeedKmh'),
    distance: _number(record.value, 'distanceKm'),
    calories: _number(record.value, 'calories').round(),
    steps: _number(record.value, 'steps').round(),
    avgHeartRate: _number(record.value, 'averageHeartRate'),
    maxHeartRate: _number(record.value, 'maxHeartRate'),
    elapsedTime: _number(record.value, 'durationSeconds').round(),
    dataPoints: points,
    synced: record.synced,
    deleted: record.deleted,
    updatedAt: record.updatedAt,
    createdAt: record.createdAt,
  );
}

class _WorkoutProgressChart extends StatefulWidget {
  final List<WorkoutDataPoint> points;

  const _WorkoutProgressChart({required this.points});

  @override
  State<_WorkoutProgressChart> createState() => _WorkoutProgressChartState();
}

class _WorkoutProgressChartState extends State<_WorkoutProgressChart> {
  final _visible = {'distance', 'calories', 'steps'};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final series = <_ProgressSeries>[
      _ProgressSeries(
        'distance',
        l10n.distance,
        AppTheme.accentTeal,
        (point) => point.distance,
      ),
      _ProgressSeries(
        'calories',
        l10n.calories,
        AppTheme.accentAmber,
        (point) => point.calories.toDouble(),
      ),
      _ProgressSeries(
        'steps',
        l10n.treadmillDetailsSteps,
        AppTheme.accentGreen,
        (point) => point.steps.toDouble(),
      ),
    ].where((series) => _visible.contains(series.id)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in [
                  _ProgressSeries(
                    'distance',
                    l10n.distance,
                    AppTheme.accentTeal,
                    (point) => point.distance,
                  ),
                  _ProgressSeries(
                    'calories',
                    l10n.calories,
                    AppTheme.accentAmber,
                    (point) => point.calories.toDouble(),
                  ),
                  _ProgressSeries(
                    'steps',
                    l10n.treadmillDetailsSteps,
                    AppTheme.accentGreen,
                    (point) => point.steps.toDouble(),
                  ),
                ])
                  FilterChip(
                    selected: _visible.contains(option.id),
                    label: Text(option.label),
                    avatar: CircleAvatar(
                      backgroundColor: option.color,
                      radius: 5,
                    ),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _visible.add(option.id);
                      }
                      if (!selected && _visible.length > 1) {
                        _visible.remove(option.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: CustomPaint(
                size: Size.infinite,
                painter: _ProgressPainter(
                  widget.points,
                  series,
                  Theme.of(context).hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSeries {
  final String id;
  final String label;
  final Color color;
  final double Function(WorkoutDataPoint) value;

  const _ProgressSeries(this.id, this.label, this.color, this.value);
}

class _ProgressPainter extends CustomPainter {
  final List<WorkoutDataPoint> points;
  final List<_ProgressSeries> series;
  final Color labelColor;

  const _ProgressPainter(this.points, this.series, this.labelColor);

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(0, 8, size.width, size.height - 30);
    final lastTime = points.last.timestamp.clamp(1, double.infinity);
    for (final item in series) {
      final maximum = item.value(points.last).clamp(1, double.infinity);
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        final offset = Offset(
          plot.left + point.timestamp / lastTime * plot.width,
          plot.bottom - item.value(point) / maximum * plot.height,
        );
        if (index == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          final previous = points[index - 1];
          final previousOffset = Offset(
            plot.left + previous.timestamp / lastTime * plot.width,
            plot.bottom - item.value(previous) / maximum * plot.height,
          );
          final controlX = (previousOffset.dx + offset.dx) / 2;
          path.cubicTo(
            controlX,
            previousOffset.dy,
            controlX,
            offset.dy,
            offset.dx,
            offset.dy,
          );
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.series != series ||
      oldDelegate.labelColor != labelColor;
}
