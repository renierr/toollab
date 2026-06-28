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

    final lastTime = state.dataPoints.last.timestamp;
    final List<WorkoutDataPoint> points = state.dataPoints
        .where((p) => p.timestamp >= lastTime - 300)
        .toList();

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

    // Apply moving average smoothing
    final List<double> smoothedSpeed = [];
    final List<double> smoothedHr = [];
    const int windowSize = 3;

    for (int i = 0; i < points.length; i++) {
      // Speed
      double speedSum = 0;
      int speedCount = 0;
      for (int w = i - windowSize ~/ 2; w <= i + windowSize ~/ 2; w++) {
        if (w >= 0 && w < points.length) {
          speedSum += points[w].speed;
          speedCount++;
        }
      }
      smoothedSpeed.add(speedSum / speedCount);

      // Heart Rate
      double hrSum = 0;
      int hrCount = 0;
      for (int w = i - windowSize ~/ 2; w <= i + windowSize ~/ 2; w++) {
        if (w >= 0 && w < points.length) {
          if (points[w].heartRate > 0) {
            hrSum += points[w].heartRate;
            hrCount++;
          }
        }
      }
      smoothedHr.add(hrCount > 0 ? hrSum / hrCount : 0.0);
    }

    // Determine min/max for normalization
    double maxSpeed = 12.0;
    double minSpeed = 0.0;
    final speedValues = smoothedSpeed.where((s) => s > 0).toList();
    if (speedValues.isNotEmpty) {
      maxSpeed = speedValues.reduce(max);
      minSpeed = speedValues.reduce(min);
    }
    if (maxSpeed == minSpeed) {
      maxSpeed += 2.0;
      minSpeed = max(0.0, minSpeed - 2.0);
    }
    final double speedRange = maxSpeed - minSpeed;

    double maxHr = 150.0;
    double minHr = 60.0;
    final hrValues = smoothedHr.where((h) => h > 0).toList();
    if (hrValues.isNotEmpty) {
      maxHr = hrValues.reduce(max);
      minHr = hrValues.reduce(min);
    }
    if (maxHr == minHr) {
      maxHr += 10.0;
      minHr = max(0.0, minHr - 10.0);
    }
    final double hrRange = maxHr - minHr;

    final speedPoints = <Offset>[];
    final hrPoints = <Offset>[];

    final double dx = points.length > 1
        ? size.width / (points.length - 1)
        : size.width;

    for (int i = 0; i < points.length; i++) {
      final x = i * dx;

      // Speed y
      final ySpeed =
          size.height -
          ((smoothedSpeed[i] - minSpeed) / speedRange) * (size.height - 16) -
          8;
      speedPoints.add(Offset(x, ySpeed));

      // Heart Rate y
      if (smoothedHr[i] > 0) {
        final yHr =
            size.height -
            ((smoothedHr[i] - minHr) / hrRange) * (size.height - 16) -
            8;
        hrPoints.add(Offset(x, yHr));
      }
    }

    // Paint subtle background grid lines
    final paintGrid = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    // Draw Speed Path
    if (speedPoints.length > 1) {
      final path = Path()..moveTo(speedPoints[0].dx, speedPoints[0].dy);
      for (int i = 0; i < speedPoints.length - 1; i++) {
        final p0 = speedPoints[i];
        final p1 = speedPoints[i + 1];
        final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }

      // Fill Gradient
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TreadmillColors.cyanMetric.withValues(alpha: 0.12),
            TreadmillColors.cyanMetric.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Line Stroke
      final linePaint = Paint()
        ..color = TreadmillColors.cyanMetric
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    }

    // Draw Heart Rate Path
    if (hrPoints.length > 1) {
      final path = Path()..moveTo(hrPoints[0].dx, hrPoints[0].dy);
      for (int i = 0; i < hrPoints.length - 1; i++) {
        final p0 = hrPoints[i];
        final p1 = hrPoints[i + 1];
        final cp1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
        final cp2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }

      // Fill Gradient
      final fillPath = Path.from(path)
        ..lineTo(hrPoints.last.dx, size.height)
        ..lineTo(hrPoints.first.dx, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TreadmillColors.redMetric.withValues(alpha: 0.12),
            TreadmillColors.redMetric.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Line Stroke
      final linePaint = Paint()
        ..color = TreadmillColors.redMetric
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDark != isDark;
  }
}
