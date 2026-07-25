import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../treadmill_control_colors.dart';
import '../treadmill_control_state.dart';
import '../treadmill_session.dart';
import '../../../l10n/app_localizations.dart';

class SessionHistoryDashboard extends StatelessWidget {
  const SessionHistoryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<TreadmillControlState>().pastSessions;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l10n.treadmillHistoryEmpty, textAlign: TextAlign.center),
        ),
      );
    }

    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final weekSessions = sessions.where((session) {
      return !DateTime.fromMillisecondsSinceEpoch(
        session.startTime,
      ).isBefore(weekStart);
    }).toList();
    final totalDistance = sessions.fold<double>(
      0,
      (sum, s) => sum + s.distance,
    );
    final totalDuration = sessions.fold<int>(
      0,
      (sum, s) => sum + s.elapsedTime,
    );
    final totalCalories = sessions.fold<int>(0, (sum, s) => sum + s.calories);
    final avgSpeed =
        sessions.fold<double>(0, (sum, s) => sum + s.avgSpeed) /
        sessions.length;
    final longest = sessions.reduce((a, b) => a.distance >= b.distance ? a : b);
    final fastest = sessions.reduce((a, b) => a.maxSpeed >= b.maxSpeed ? a : b);
    final heartRateSessions = sessions
        .where((session) => session.avgHeartRate > 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.treadmillHistoryOverview,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.treadmillHistoryOverviewSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 16),
        _MetricGrid(
          children: [
            _Metric(
              label: l10n.treadmillHistoryTotalDistance,
              value: '${totalDistance.toStringAsFixed(1)} km',
              icon: Icons.route_outlined,
              color: TreadmillColors.cyanMetric,
            ),
            _Metric(
              label: l10n.treadmillHistoryTotalDuration,
              value: _duration(totalDuration),
              icon: Icons.timer_outlined,
              color: TreadmillColors.greenMetric,
            ),
            _Metric(
              label: l10n.treadmillHistoryTotalCalories,
              value: '$totalCalories kcal',
              icon: Icons.local_fire_department_outlined,
              color: TreadmillColors.amberMetric,
            ),
            _Metric(
              label: l10n.treadmillHistoryAverageSpeed,
              value: '${avgSpeed.toStringAsFixed(1)} km/h',
              icon: Icons.speed_outlined,
              color: TreadmillColors.redMetric,
            ),
            _Metric(
              label: l10n.treadmillHistoryWorkoutCount,
              value: '${sessions.length}',
              icon: Icons.directions_run_outlined,
              color: TreadmillColors.greenMetric,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.treadmillHistoryDistanceLastSevenDays,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.treadmillHistoryDistanceChartSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 12),
        _WeeklyChart(sessions: weekSessions),
        if (heartRateSessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.treadmillHistoryHeartRate,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _HeartRateCard(sessions: heartRateSessions),
        ],
        const SizedBox(height: 24),
        Text(
          l10n.treadmillHistoryPersonalBests,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _BestCard(
          icon: Icons.workspace_premium_outlined,
          label: l10n.treadmillHistoryLongestRun,
          value: '${longest.distance.toStringAsFixed(2)} km',
          subtitle: DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(DateTime.fromMillisecondsSinceEpoch(longest.startTime)),
        ),
        const SizedBox(height: 8),
        _BestCard(
          icon: Icons.bolt_outlined,
          label: l10n.treadmillHistoryTopSpeed,
          value: '${fastest.maxSpeed.toStringAsFixed(1)} km/h',
          subtitle:
              '${l10n.treadmillHistoryAverage}: ${fastest.avgSpeed.toStringAsFixed(1)} km/h',
        ),
      ],
    );
  }
}

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';

class _MetricGrid extends StatelessWidget {
  final List<_Metric> children;
  const _MetricGrid({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map(
            (child) => SizedBox(
              width: constraints.maxWidth < 500
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4,
              child: child,
            ),
          )
          .toList(),
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  const _BestCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: TreadmillColors.amberMetric),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
  );
}

class _HeartRateCard extends StatelessWidget {
  final List<TreadmillSession> sessions;

  const _HeartRateCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final totalDuration = sessions.fold<int>(
      0,
      (sum, session) => sum + session.elapsedTime,
    );
    final weightedAverage = totalDuration == 0
        ? sessions.fold<double>(
                0,
                (sum, session) => sum + session.avgHeartRate,
              ) /
              sessions.length
        : sessions.fold<double>(
                0,
                (sum, session) =>
                    sum + session.avgHeartRate * session.elapsedTime,
              ) /
              totalDuration;
    final peak = sessions.fold<double>(
      0,
      (maxHeartRate, session) => max(maxHeartRate, session.maxHeartRate),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TreadmillColors.redMetric.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: TreadmillColors.redMetric,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.treadmillHistoryHeartRateSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _HeartRateValue(
                    label: l10n.treadmillHistoryRestingAverage,
                    value: '${weightedAverage.round()} bpm',
                  ),
                ),
                Container(width: 1, height: 42, color: theme.dividerColor),
                Expanded(
                  child: _HeartRateValue(
                    label: l10n.treadmillHistoryPeakHeartRate,
                    value: '${peak.round()} bpm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _HeartRateTrend(sessions: sessions),
          ],
        ),
      ),
    );
  }
}

class _HeartRateValue extends StatelessWidget {
  final String label;
  final String value;

  const _HeartRateValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: TreadmillColors.redMetric,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _HeartRateTrend extends StatelessWidget {
  final List<TreadmillSession> sessions;

  const _HeartRateTrend({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
    final values = days.map((day) {
      final daySessions = sessions.where((session) {
        final date = DateTime.fromMillisecondsSinceEpoch(session.startTime);
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).toList();
      if (daySessions.isEmpty) return null;
      return daySessions.fold<double>(
            0,
            (sum, session) => sum + session.avgHeartRate,
          ) /
          daySessions.length;
    }).toList();
    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _HeartRateTrendPainter(
          values: values,
          lineColor: TreadmillColors.redMetric,
          gridColor: Theme.of(context).dividerColor.withValues(alpha: 0.45),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        DateFormat.E(
                          Localizations.localeOf(context).toString(),
                        ).format(day),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _HeartRateTrendPainter extends CustomPainter {
  final List<double?> values;
  final Color lineColor;
  final Color gridColor;

  const _HeartRateTrendPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 18.0;
    const axisWidth = 36.0;
    final chartHeight = size.height - labelHeight;
    final knownValues = values.whereType<double>().toList();
    if (knownValues.isEmpty) return;
    final minValue = max(40, knownValues.reduce(min) - 10).toDouble();
    final maxValue = max(
      minValue + 20,
      knownValues.reduce(max) + 10,
    ).toDouble();
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 1; index < 4; index++) {
      final y = chartHeight * index / 4;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
    }
    final labelStyle = TextStyle(color: gridColor, fontSize: 10);
    for (final fraction in [0.0, 0.5, 1.0]) {
      final value = maxValue - (maxValue - minValue) * fraction;
      final label = TextPainter(
        text: TextSpan(text: '${value.round()}', style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 2);
      label.paint(canvas, Offset(0, chartHeight * fraction - label.height / 2));
    }
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = lineColor;
    final points = <Offset?>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        points.add(null);
        continue;
      }
      final x =
          axisWidth + (size.width - axisWidth) * index / (values.length - 1);
      final y =
          chartHeight -
          (value - minValue) / (maxValue - minValue) * chartHeight;
      points.add(Offset(x, y));
    }
    for (var index = 0; index < points.length; index++) {
      final start = points[index];
      if (start == null || (index > 0 && points[index - 1] != null)) continue;
      final path = Path()..moveTo(start.dx, start.dy);
      var pointIndex = index + 1;
      while (pointIndex < points.length && points[pointIndex] != null) {
        final end = points[pointIndex]!;
        final previous = points[pointIndex - 1]!;
        final controlX = (previous.dx + end.dx) / 2;
        path.cubicTo(controlX, previous.dy, controlX, end.dy, end.dx, end.dy);
        pointIndex++;
      }
      canvas.drawPath(path, linePaint);
    }
    for (final point in points.whereType<Offset>()) {
      canvas.drawCircle(point, 3.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartRateTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<TreadmillSession> sessions;
  const _WeeklyChart({required this.sessions});
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
    final distances = days
        .map(
          (day) => sessions
              .where((session) {
                final date = DateTime.fromMillisecondsSinceEpoch(
                  session.startTime,
                );
                return date.year == day.year &&
                    date.month == day.month &&
                    date.day == day.day;
              })
              .fold<double>(0, (sum, session) => sum + session.distance),
        )
        .toList();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _DistanceChartPainter(
              values: distances,
              barColor: TreadmillColors.cyanMetric,
              lineColor: TreadmillColors.greenMetric,
              gridColor: theme.dividerColor.withValues(alpha: 0.45),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            DateFormat.E(
                              Localizations.localeOf(context).toString(),
                            ).format(day),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistanceChartPainter extends CustomPainter {
  final List<double> values;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;

  const _DistanceChartPainter({
    required this.values,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const axisWidth = 36.0;
    const labelHeight = 20.0;
    const valueLabelHeight = 18.0;
    final chartHeight = size.height - labelHeight - valueLabelHeight;
    final maxValue = max(1.0, values.reduce(max));
    final axisMaximum = (maxValue * 1.2).ceilToDouble();
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: gridColor, fontSize: 10);
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = valueLabelHeight + chartHeight * fraction;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), gridPaint);
      final value = axisMaximum * (1 - fraction);
      final label = TextPainter(
        text: TextSpan(
          text: '${value.toStringAsFixed(0)} km',
          style: labelStyle,
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: axisWidth - 2);
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    final step = (size.width - axisWidth) / values.length;
    final barPaint = Paint()..color = barColor.withValues(alpha: 0.6);
    final pointPaint = Paint()..color = lineColor;
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final centerX = axisWidth + step * (index + 0.5);
      final barHeight = chartHeight * value / axisMaximum;
      final y = valueLabelHeight + chartHeight - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - step * 0.22, y, step * 0.44, barHeight),
          const Radius.circular(5),
        ),
        barPaint,
      );
      final valueLabel = TextPainter(
        text: TextSpan(
          text: value == 0 ? '0' : value.toStringAsFixed(1),
          style: TextStyle(
            color: barColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      valueLabel.paint(
        canvas,
        Offset(
          centerX - valueLabel.width / 2,
          max(0, y - valueLabel.height - 3),
        ),
      );
      points.add(Offset(centerX, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final point = points[index];
      final controlX = (previous.dx + point.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        point.dy,
        point.dx,
        point.dy,
      );
    }
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DistanceChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.barColor != barColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
