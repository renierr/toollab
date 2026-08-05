import 'dart:math';

import 'package:flutter/material.dart';

import '../treadmill_control_colors.dart';
import '../treadmill_session.dart';

class WorkoutInclineChart extends StatelessWidget {
  final List<WorkoutDataPoint> points;
  final double height;

  const WorkoutInclineChart({
    super.key,
    required this.points,
    this.height = 70,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _InclinePainter(
          points: points,
          gridColor: theme.colorScheme.outline.withValues(alpha: 0.25),
          labelColor: theme.hintColor,
        ),
      ),
    );
  }
}

class _InclinePainter extends CustomPainter {
  final List<WorkoutDataPoint> points;
  final Color gridColor;
  final Color labelColor;

  const _InclinePainter({
    required this.points,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final plot = Rect.fromLTRB(34, 6, size.width - 6, size.height - 6);
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxIncline = max(
      1.0,
      points.map((point) => point.incline).reduce(max).ceilToDouble(),
    );
    final startTime = points.first.timestamp;
    final span = max(1, points.last.timestamp - startTime);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 1.0]) {
      final y = plot.bottom - fraction * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final painter = TextPainter(
        text: TextSpan(
          text: '${(maxIncline * fraction).toStringAsFixed(0)}%',
          style: TextStyle(color: labelColor, fontSize: 9.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(plot.left - 4 - painter.width, y - painter.height / 2),
      );
    }

    double xOf(int index) =>
        plot.left + ((points[index].timestamp - startTime) / span) * plot.width;
    double yOf(int index) =>
        plot.bottom - (points[index].incline / maxIncline) * plot.height;

    final path = Path()..moveTo(xOf(0), yOf(0));
    double previousY = yOf(0);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(xOf(i), previousY);
      path.lineTo(xOf(i), yOf(i));
      previousY = yOf(i);
    }

    final fill = Path.from(path)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = TreadmillColors.amberMetric.withValues(alpha: 0.2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = TreadmillColors.amberMetric
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _InclinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.labelColor != labelColor;
}
