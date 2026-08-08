import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_record.dart';

class HealthWorkoutTrendChart extends StatelessWidget {
  final List<HealthRecord> workouts;

  const HealthWorkoutTrendChart({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: CustomPaint(
      size: Size.infinite,
      painter: _HealthWorkoutTrendPainter(
        workouts: workouts,
        lineColor: AppTheme.accentTeal,
        gridColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        labelColor: Theme.of(context).hintColor,
      ),
    ),
  );
}

class _HealthWorkoutTrendPainter extends CustomPainter {
  final List<HealthRecord> workouts;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  const _HealthWorkoutTrendPainter({
    required this.workouts,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final values = List<double>.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      return workouts
          .where((workout) {
            final date = DateTime.fromMillisecondsSinceEpoch(workout.startTime);
            return date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold(0.0, (sum, workout) {
            return sum +
                ((workout.value['distanceKm'] as num?)?.toDouble() ?? 0);
          });
    });
    final maxValue = max(1.0, values.reduce(max));
    final plot = Rect.fromLTWH(8, 8, size.width - 16, size.height - 30);
    final barWidth = plot.width / values.length * 0.56;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    for (var index = 0; index < values.length; index++) {
      final height = values[index] / maxValue * plot.height;
      final x = plot.left + plot.width * (index + 0.5) / values.length;
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barWidth / 2, plot.bottom - height, barWidth, height),
        const Radius.circular(5),
      );
      canvas.drawRRect(bar, Paint()..color = lineColor);
      _label(
        canvas,
        '${today.subtract(Duration(days: 6 - index)).day}',
        Offset(x, plot.bottom + 6),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(_HealthWorkoutTrendPainter oldDelegate) =>
      oldDelegate.workouts != workouts ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
