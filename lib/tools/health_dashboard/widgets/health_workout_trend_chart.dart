import 'dart:math';

import 'package:flutter/material.dart';

enum HealthTrendChartStyle { bars, line }

class HealthWorkoutTrendChart extends StatelessWidget {
  final List<double?> values;
  final String unit;
  final Color color;
  final HealthTrendChartStyle style;

  const HealthWorkoutTrendChart({
    super.key,
    required this.values,
    required this.unit,
    required this.color,
    this.style = HealthTrendChartStyle.bars,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: CustomPaint(
      size: Size.infinite,
      painter: _HealthWorkoutTrendPainter(
        values: values,
        unit: unit,
        lineColor: color,
        style: style,
        gridColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        labelColor: Theme.of(context).hintColor,
      ),
    ),
  );
}

class _HealthWorkoutTrendPainter extends CustomPainter {
  final List<double?> values;
  final String unit;
  final Color lineColor;
  final HealthTrendChartStyle style;
  final Color gridColor;
  final Color labelColor;

  const _HealthWorkoutTrendPainter({
    required this.values,
    required this.unit,
    required this.lineColor,
    required this.style,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minimum = unit == 'km'
        ? 1.0
        : unit == 'bpm'
        ? 60.0
        : 1.0;
    final rawMaxValue = max(minimum, values.whereType<double>().fold(0.0, max));
    final rawMinValue = values.whereType<double>().fold(rawMaxValue, min);
    final padding = max((rawMaxValue - rawMinValue).abs() * 0.15, 1.0);
    final minValue = style == HealthTrendChartStyle.line
        ? max(0, rawMinValue - padding)
        : 0.0;
    final maxValue = style == HealthTrendChartStyle.line
        ? rawMaxValue + padding
        : rawMaxValue;
    final plot = Rect.fromLTWH(34, 14, size.width - 42, size.height - 44);
    final barWidth = plot.width / values.length * 0.56;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(
        canvas,
        _formatValue(minValue + (maxValue - minValue) * (2 - index) / 2),
        Offset(plot.left - 5, y - 6),
        alignRight: true,
      );
    }
    final segments = <List<Offset>>[];
    var segment = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final height =
          ((value ?? minValue) - minValue) /
          (maxValue - minValue) *
          plot.height;
      final x = plot.left + plot.width * (index + 0.5) / values.length;
      if (style == HealthTrendChartStyle.bars) {
        final bar = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - barWidth / 2,
            plot.bottom - height,
            barWidth,
            height,
          ),
          const Radius.circular(5),
        );
        canvas.drawRRect(bar, Paint()..color = lineColor);
      } else if (value != null) {
        segment.add(Offset(x, plot.bottom - height));
      } else if (segment.isNotEmpty) {
        segments.add(segment);
        segment = <Offset>[];
      }
      if (value != null && value > 0) {
        _label(
          canvas,
          _formatValue(value),
          Offset(x, plot.bottom - height - 16),
          centered: true,
        );
      }
      _label(
        canvas,
        '${today.subtract(Duration(days: 6 - index)).day}',
        Offset(x, plot.bottom + 6),
      );
    }
    if (segment.isNotEmpty) segments.add(segment);
    if (style == HealthTrendChartStyle.line) {
      final paint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final points in segments) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (var index = 1; index < points.length; index++) {
          final previous = points[index - 1];
          final point = points[index];
          path.quadraticBezierTo(
            previous.dx + (point.dx - previous.dx) / 2,
            previous.dy,
            point.dx,
            point.dy,
          );
        }
        canvas.drawPath(path, paint);
        for (final point in points) {
          canvas.drawCircle(point, 4, Paint()..color = lineColor);
        }
      }
    }
  }

  String _formatValue(double value) => switch (unit) {
    'km' => '${value.toStringAsFixed(value >= 10 ? 0 : 1)} km',
    'kg' => '${value.toStringAsFixed(1)} kg',
    'bpm' => '${value.round()} bpm',
    'steps' => value.round().toString(),
    'min' => '${value.round()} min',
    'calories' => value.round().toString(),
    _ => value.round().toString(),
  };

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool centered = false,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = alignRight
        ? anchor.dx - painter.width
        : centered
        ? anchor.dx - painter.width / 2
        : anchor.dx;
    painter.paint(canvas, Offset(x, anchor.dy));
  }

  @override
  bool shouldRepaint(_HealthWorkoutTrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.unit != unit ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.style != style ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
