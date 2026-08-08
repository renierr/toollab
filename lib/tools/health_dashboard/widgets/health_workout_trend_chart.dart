import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

enum HealthTrendChartStyle { bars, line }

class HealthWorkoutTrendChart extends StatelessWidget {
  final List<double?> values;
  final String unit;
  final Color color;
  final HealthTrendChartStyle style;
  final List<double?>? overlayValues;
  final String? overlayUnit;
  final Color? overlayColor;
  final DateTime? endDate;
  final ValueChanged<int>? onDayTap;

  const HealthWorkoutTrendChart({
    super.key,
    required this.values,
    required this.unit,
    required this.color,
    this.style = HealthTrendChartStyle.bars,
    this.overlayValues,
    this.overlayUnit,
    this.overlayColor,
    this.endDate,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 170,
    child: LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onDayTap == null
            ? null
            : (details) {
                final plotWidth =
                    constraints.maxWidth - (overlayValues == null ? 42 : 76);
                final ratio = ((details.localPosition.dx - 34) / plotWidth)
                    .clamp(0.0, 0.999999);
                onDayTap!((ratio * values.length).floor());
              },
        child: CustomPaint(
          key: ValueKey(endDate),
          size: Size.infinite,
          painter: _HealthWorkoutTrendPainter(
            values: values,
            unit: unit,
            lineColor: color,
            style: style,
            overlayValues: overlayValues,
            overlayUnit: overlayUnit,
            overlayColor: overlayColor,
            endDate: endDate,
            locale: Localizations.localeOf(context).toString(),
            gridColor: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.2),
            labelColor: Theme.of(context).hintColor,
          ),
        ),
      ),
    ),
  );
}

class _HealthWorkoutTrendPainter extends CustomPainter {
  final List<double?> values;
  final String unit;
  final Color lineColor;
  final HealthTrendChartStyle style;
  final List<double?>? overlayValues;
  final String? overlayUnit;
  final Color? overlayColor;
  final DateTime? endDate;
  final String locale;
  final Color gridColor;
  final Color labelColor;

  const _HealthWorkoutTrendPainter({
    required this.values,
    required this.unit,
    required this.lineColor,
    required this.style,
    this.overlayValues,
    this.overlayUnit,
    this.overlayColor,
    this.endDate,
    required this.locale,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = endDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minimum = unit == 'km'
        ? 1.0
        : unit == 'bpm'
        ? 60.0
        : 1.0;
    final rawMaxValue = math.max(
      minimum,
      values.whereType<double>().fold(0.0, math.max),
    );
    final rawMinValue = values.whereType<double>().fold(rawMaxValue, math.min);
    final padding = math.max((rawMaxValue - rawMinValue).abs() * 0.15, 1.0);
    final minValue = style == HealthTrendChartStyle.line
        ? math.max(0, rawMinValue - padding)
        : 0.0;
    final maxValue = style == HealthTrendChartStyle.line
        ? rawMaxValue + padding
        : rawMaxValue;
    final plot = Rect.fromLTWH(
      34,
      14,
      size.width - (overlayValues == null ? 42 : 76),
      size.height - 52,
    );
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
        _dateLabel(today.subtract(Duration(days: 6 - index))),
        Offset(x, plot.bottom + 4),
        centered: true,
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
        canvas.drawPath(_smoothPath(points), paint);
        for (final point in points) {
          canvas.drawCircle(point, 4, Paint()..color = lineColor);
        }
      }
    }
    _drawOverlay(canvas, plot);
  }

  void _drawOverlay(Canvas canvas, Rect plot) {
    final values = overlayValues;
    if (values == null || values.whereType<double>().isEmpty) return;
    final min = values.whereType<double>().reduce((a, b) => a < b ? a : b);
    final maximum = values.whereType<double>().reduce((a, b) => a > b ? a : b);
    final padding = math.max((maximum - min).abs() * 0.15, 1.0).toDouble();
    final lower = min - padding;
    final upper = maximum + padding;
    _label(canvas, _formatOverlay(upper), Offset(plot.right + 5, plot.top - 6));
    _label(
      canvas,
      _formatOverlay(lower),
      Offset(plot.right + 5, plot.bottom - 6),
    );
    final segments = <List<Offset>>[];
    var segment = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) {
        if (segment.isNotEmpty) segments.add(segment);
        segment = <Offset>[];
        continue;
      }
      final x = plot.left + plot.width * (index + 0.5) / values.length;
      final y = plot.bottom - (value - lower) / (upper - lower) * plot.height;
      segment.add(Offset(x, y));
      _label(canvas, _formatOverlay(value), Offset(x, y - 16), centered: true);
    }
    if (segment.isNotEmpty) segments.add(segment);
    final paint = Paint()
      ..color = overlayColor ?? Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final points in segments) {
      canvas.drawPath(_smoothPath(points), paint);
      for (final point in points) {
        canvas.drawCircle(
          point,
          4,
          Paint()..color = overlayColor ?? Colors.red,
        );
      }
    }
  }

  Path _smoothPath(List<Offset> points) {
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
    return path;
  }

  String _dateLabel(DateTime date) =>
      '${DateFormat.E(locale).format(date)}\n${date.day} ${DateFormat.MMM(locale).format(date)}';

  String _formatValue(double value) => switch (unit) {
    'km' => '${value.toStringAsFixed(value >= 10 ? 0 : 1)} km',
    'kg' => '${value.toStringAsFixed(1)} kg',
    'bpm' => '${value.round()} bpm',
    'steps' => value.round().toString(),
    'min' => _duration(value.round()),
    'calories' => value.round().toString(),
    _ => value.round().toString(),
  };

  String _duration(int minutes) =>
      '${minutes ~/ 60}h ${minutes.remainder(60)}m';

  String _formatOverlay(double value) =>
      overlayUnit == 'bpm' ? '${value.round()} bpm' : '${value.round()}';

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
      oldDelegate.overlayValues != overlayValues ||
      oldDelegate.overlayUnit != overlayUnit ||
      oldDelegate.overlayColor != overlayColor ||
      oldDelegate.endDate != endDate ||
      oldDelegate.locale != locale ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
