import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A bare trend line for the recent values of one metric — no axes, no labels,
/// meant to sit behind or beside a headline figure. Gaps in the series are
/// bridged, so a metric measured every other day still reads as a curve.
class Sparkline extends StatelessWidget {
  final List<double?> values;
  final Color color;
  final double strokeWidth;
  final double opacity;

  /// Fades a wash of [color] from the curve down to the baseline.
  final bool filled;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.strokeWidth = 2,
    this.opacity = 0.55,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (values.whereType<double>().length < 2) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(
        values: values,
        color: color,
        strokeWidth: strokeWidth,
        opacity: opacity,
        filled: filled,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double?> values;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool filled;

  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final readings = values.whereType<double>();
    final lowest = readings.reduce(math.min);
    final highest = readings.reduce(math.max);
    final span = math.max(highest - lowest, 1e-9);
    final inset = strokeWidth;
    final top = inset;
    final height = size.height - inset * 2;

    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) continue;
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      points.add(Offset(x, top + height * (1 - (value - lowest) / span)));
    }
    if (points.length < 2) return;

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

    if (filled) {
      final area = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: opacity * 0.35),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.opacity != opacity ||
      old.filled != filled;
}
