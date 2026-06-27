import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../treadmill_control_state.dart';
import '../treadmill_control_colors.dart';
import '../treadmill_session.dart';

class WorkoutChart extends StatelessWidget {
  const WorkoutChart({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state.dataPoints.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Start workout to visualize graph',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      );
    }

    final List<WorkoutDataPoint> points = state.dataPoints.length > 60
        ? state.dataPoints.sublist(state.dataPoints.length - 60)
        : state.dataPoints;

    return Container(
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: CustomPaint(
        painter: _ChartPainter(points: points, isDark: isDark),
        child: Container(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<WorkoutDataPoint> points;
  final bool isDark;

  _ChartPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintSpeed = Paint()
      ..color = TreadmillColors.cyanMetric
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintHr = Paint()
      ..color = TreadmillColors.redMetric
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintGrid = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    double maxSpeed = 12.0;
    double maxHr = 180.0;
    double minHr = 60.0;

    for (final p in points) {
      if (p.speed > maxSpeed) {
        maxSpeed = p.speed;
      }
      if (p.heartRate > maxHr) {
        maxHr = p.heartRate.toDouble();
      }
      if (p.heartRate > 0 && p.heartRate < minHr) {
        minHr = p.heartRate.toDouble();
      }
    }

    final double hrRange = max(40.0, maxHr - minHr);

    final speedPoints = <Offset>[];
    final hrPoints = <Offset>[];

    final double dx = points.length > 1
        ? size.width / (points.length - 1)
        : size.width;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = i * dx;

      final ySpeed = size.height - (p.speed / maxSpeed) * size.height;
      speedPoints.add(Offset(x, ySpeed));

      if (p.heartRate > 0) {
        final yHr =
            size.height - ((p.heartRate - minHr) / hrRange) * size.height;
        hrPoints.add(Offset(x, yHr));
      }
    }

    if (speedPoints.length > 1) {
      final path = Path()..moveTo(speedPoints[0].dx, speedPoints[0].dy);
      for (int i = 1; i < speedPoints.length; i++) {
        path.lineTo(speedPoints[i].dx, speedPoints[i].dy);
      }
      canvas.drawPath(path, paintSpeed);
    }

    if (hrPoints.length > 1) {
      final path = Path()..moveTo(hrPoints[0].dx, hrPoints[0].dy);
      for (int i = 1; i < hrPoints.length; i++) {
        path.lineTo(hrPoints[i].dx, hrPoints[i].dy);
      }
      canvas.drawPath(path, paintHr);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDark != isDark;
  }
}
