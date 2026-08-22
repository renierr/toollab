import 'dart:math';

import 'package:flutter/material.dart';

import 'workout_colors.dart';
import 'workout_session.dart';
import 'workout_details_stats.dart';
import 'workout_chart_legend.dart';

/// Speed (stepped area, left axis) and heart rate (smoothed line, right axis)
/// over workout time.
class WorkoutSessionChart extends StatelessWidget {
  final List<WorkoutDataPoint> points;
  final String speedLabel;
  final String heartRateLabel;
  final double height;

  const WorkoutSessionChart({
    super.key,
    required this.points,
    required this.speedLabel,
    required this.heartRateLabel,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeartRate = points.any((point) => point.heartRate > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkoutChartLegend(
          entries: [
            WorkoutLegendEntry(speedLabel, TreadmillColors.cyanMetric),
            if (hasHeartRate)
              WorkoutLegendEntry(heartRateLabel, TreadmillColors.redMetric),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SessionChartPainter(
              points: points,
              hasHeartRate: hasHeartRate,
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.25),
              labelColor: theme.hintColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionChartPainter extends CustomPainter {
  final List<WorkoutDataPoint> points;
  final bool hasHeartRate;
  final Color gridColor;
  final Color labelColor;

  const _SessionChartPainter({
    required this.points,
    required this.hasHeartRate,
    required this.gridColor,
    required this.labelColor,
  });

  static const int _gridLines = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final plot = Rect.fromLTRB(
      34,
      10,
      size.width - (hasHeartRate ? 38 : 6),
      size.height - 20,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    double maxSpeed = 0;
    double minHr = double.infinity;
    double maxHr = 0;
    for (final point in points) {
      maxSpeed = max(maxSpeed, point.speed);
      if (point.heartRate > 0) {
        minHr = min(minHr, point.heartRate.toDouble());
        maxHr = max(maxHr, point.heartRate.toDouble());
      }
    }
    final speedTop = max(2.0, (maxSpeed / 2).ceil() * 2.0);
    final hrLow = minHr.isFinite ? (minHr / 10).floor() * 10.0 : 60.0;
    final hrHigh = maxHr > 0 ? (maxHr / 10).ceil() * 10.0 : 180.0;
    final hrRange = max(10.0, hrHigh - hrLow);

    final startTime = points.first.timestamp;
    final span = max(1, points.last.timestamp - startTime);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i <= _gridLines; i++) {
      final fraction = i / _gridLines;
      final y = plot.bottom - fraction * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(
        canvas,
        (speedTop * fraction).toStringAsFixed(speedTop >= 10 ? 0 : 1),
        Offset(plot.left - 4, y),
        alignRight: true,
      );
      if (hasHeartRate) {
        _label(
          canvas,
          (hrLow + hrRange * fraction).round().toString(),
          Offset(plot.right + 4, y),
        );
      }
    }

    for (int i = 0; i <= 2; i++) {
      final fraction = i / 2;
      final seconds = startTime + (span * fraction).round();
      _label(
        canvas,
        formatWorkoutClock(seconds),
        Offset(plot.left + plot.width * fraction, plot.bottom + 5),
        center: i == 1,
        alignRight: i == 2,
        below: true,
      );
    }

    double xOf(WorkoutDataPoint point) =>
        plot.left + ((point.timestamp - startTime) / span) * plot.width;

    final speedLine = Path()
      ..moveTo(
        xOf(points.first),
        plot.bottom - (points.first.speed / speedTop) * plot.height,
      );
    double previousY =
        plot.bottom - (points.first.speed / speedTop) * plot.height;
    for (int i = 1; i < points.length; i++) {
      final x = xOf(points[i]);
      final y = plot.bottom - (points[i].speed / speedTop) * plot.height;
      speedLine.lineTo(x, previousY);
      speedLine.lineTo(x, y);
      previousY = y;
    }

    final fill = Path.from(speedLine)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TreadmillColors.cyanMetric.withValues(alpha: 0.28),
            TreadmillColors.cyanMetric.withValues(alpha: 0.0),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      speedLine,
      Paint()
        ..color = TreadmillColors.cyanMetric
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (!hasHeartRate) return;

    final smoothed = _smoothedHeartRates();
    final hrPoints = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final value = smoothed[i];
      if (value == null) continue;
      hrPoints.add(
        Offset(
          xOf(points[i]),
          plot.bottom - ((value - hrLow) / hrRange) * plot.height,
        ),
      );
    }
    if (hrPoints.length < 2) return;

    final hrPath = Path()..moveTo(hrPoints.first.dx, hrPoints.first.dy);
    for (int i = 0; i < hrPoints.length - 1; i++) {
      final current = hrPoints[i];
      final next = hrPoints[i + 1];
      final midX = current.dx + (next.dx - current.dx) / 2;
      hrPath.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }
    canvas.drawPath(
      hrPath,
      Paint()
        ..color = TreadmillColors.redMetric
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  List<double?> _smoothedHeartRates() {
    const window = 2;
    return [
      for (int i = 0; i < points.length; i++)
        if (points[i].heartRate <= 0)
          null
        else
          () {
            double sum = 0;
            int count = 0;
            for (int w = i - window; w <= i + window; w++) {
              if (w < 0 || w >= points.length) continue;
              if (points[w].heartRate <= 0) continue;
              sum += points[w].heartRate;
              count++;
            }
            return count == 0 ? points[i].heartRate.toDouble() : sum / count;
          }(),
    ];
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool center = false,
    bool below = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 9.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? anchor.dx - painter.width
        : center
        ? anchor.dx - painter.width / 2
        : anchor.dx;
    final dy = below ? anchor.dy : anchor.dy - painter.height / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SessionChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
