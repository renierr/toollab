import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_database.dart';
import '../health_record.dart';

class HealthMetricDaySection extends StatelessWidget {
  final String type;
  final String valueKey;
  final String unit;
  final Color color;
  final DateTime day;
  final bool sum;

  const HealthMetricDaySection({
    super.key,
    required this.type,
    required this.valueKey,
    required this.unit,
    required this.color,
    required this.day,
    required this.sum,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<HealthRecord>>(
    key: ValueKey('$type-${day.toIso8601String()}'),
    future: HealthDatabase.instance.recordsForDay(type: type, day: day),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox.shrink();
      }
      final readings = <_Reading>[];
      for (final record in snapshot.data ?? const <HealthRecord>[]) {
        final value = (record.value[valueKey] as num?)?.toDouble();
        if (value == null) continue;
        readings.add(_Reading(time: record.startTime, value: value));
      }
      if (readings.length < 2) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).healthDashboardSelectedDay,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 190,
                child: CustomPaint(
                  painter: _MetricDayPainter(
                    readings: readings,
                    color: color,
                    unit: unit,
                    sum: sum,
                    gridColor: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                    labelColor: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _Reading {
  final int time;
  final double value;

  const _Reading({required this.time, required this.value});
}

class _MetricDayPainter extends CustomPainter {
  final List<_Reading> readings;
  final Color color;
  final String unit;
  final bool sum;
  final Color gridColor;
  final Color labelColor;

  const _MetricDayPainter({
    required this.readings,
    required this.color,
    required this.unit,
    required this.sum,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 46);
    final min = readings.map((reading) => reading.value).reduce(math.min);
    final max = readings.map((reading) => reading.value).reduce(math.max);
    final padding = math.max((max - min) * .15, 1).toDouble();
    final lower = sum ? 0.0 : math.max(0, min - padding);
    final upper = math.max(lower + 1, max + padding);
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(
        canvas,
        '${(lower + (upper - lower) * (2 - index) / 2).round()}',
        Offset(plot.left - 5, y - 6),
        right: true,
      );
    }
    final points = <Offset>[];
    for (var index = 0; index < readings.length; index++) {
      final reading = readings[index];
      final date = DateTime.fromMillisecondsSinceEpoch(reading.time);
      final x = plot.left + plot.width * (date.hour * 60 + date.minute) / 1440;
      final y =
          plot.bottom - (reading.value - lower) / (upper - lower) * plot.height;
      final point = Offset(x, y);
      points.add(point);
      canvas.drawCircle(point, 3.5, Paint()..color = color);
    }
    canvas.drawPath(
      _smoothPath(points),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (final hour in [0, 6, 12, 18, 24]) {
      final x = plot.left + plot.width * hour / 24;
      _label(
        canvas,
        '${hour.toString().padLeft(2, '0')}:00',
        Offset(x, plot.bottom + 6),
        center: true,
      );
    }
    _label(canvas, unit, Offset(plot.left, 0));
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

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool right = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        right
            ? anchor.dx - painter.width
            : center
            ? anchor.dx - painter.width / 2
            : anchor.dx,
        anchor.dy,
      ),
    );
  }

  @override
  bool shouldRepaint(_MetricDayPainter oldDelegate) =>
      oldDelegate.readings != readings ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
