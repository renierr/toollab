import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/workout/workout_colors.dart';
import 'package:tool_lab/widgets/workout/workout_session.dart';

class SessionHeartRateCard extends StatelessWidget {
  final List<TreadmillSession> sessions;

  const SessionHeartRateCard({super.key, required this.sessions});

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
