import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/widgets/workout/workout_colors.dart';
import 'package:tool_lab/widgets/workout/workout_session.dart';

class SessionWeeklyChart extends StatelessWidget {
  final List<TreadmillSession> sessions;

  const SessionWeeklyChart({super.key, required this.sessions});

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
