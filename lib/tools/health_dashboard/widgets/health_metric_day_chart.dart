import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../store/health_queries.dart';
import '../health_record.dart';
import '../health_record_values.dart';
import 'package:tool_lab/helpers/health_value_format.dart';
import 'package:tool_lab/widgets/health_chart_tooltip.dart';
import 'health_record_stat_item.dart';

/// The selected day behind a metric's week: its readings over 24 hours plus the
/// numbers behind that curve.
///
/// Every metric with more than one reading that day gets this, sessions
/// included - a day with two workouts is as much a curve as a day of heart rate
/// samples. Totalled metrics read as hourly bars and measured ones as a line,
/// the same split the seven-day chart above it uses.
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
    key: ValueKey('$type-$valueKey-${day.toIso8601String()}'),
    future: HealthQueries.instance.recordsForDay(type: type, day: day),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SizedBox.shrink();
      }
      final readings = <HealthDayReading>[
        for (final record in snapshot.data ?? const <HealthRecord>[])
          if (healthRecordValue(record, valueKey) case final value?)
            (t: record.startTime, v: value),
      ]..sort((first, second) => first.t.compareTo(second.t));
      if (readings.length < 2) return const SizedBox.shrink();
      final l10n = AppLocalizations.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            l10n.healthDashboardSelectedDay,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HealthMetricDayChart(
                readings: readings,
                unit: unit,
                color: color,
                sum: sum,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DayStats(readings: readings, unit: unit, color: color, sum: sum),
        ],
      );
    },
  );
}

/// One reading of a metric within the day.
typedef HealthDayReading = ({int t, double v});

class HealthMetricDayChart extends StatefulWidget {
  final List<HealthDayReading> readings;
  final String unit;
  final Color color;
  final bool sum;

  const HealthMetricDayChart({
    super.key,
    required this.readings,
    required this.unit,
    required this.color,
    required this.sum,
  });

  @override
  State<HealthMetricDayChart> createState() => _HealthMetricDayChartState();
}

class _HealthMetricDayChartState extends State<HealthMetricDayChart> {
  double? _markerX;

  static const _height = 190.0;
  static const _plotLeft = 34.0;
  static const _plotRightInset = 14.0;

  List<double?> get _hourly {
    final totals = List<double?>.filled(24, null);
    for (final reading in widget.readings) {
      final hour = DateTime.fromMillisecondsSinceEpoch(reading.t).hour;
      totals[hour] = (totals[hour] ?? 0) + reading.v;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final hourly = widget.sum ? _hourly : null;
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final marker = _markerX == null
              ? null
              : _readingAt(constraints.maxWidth, hourly);
          return MouseRegion(
            onHover: (event) =>
                setState(() => _markerX = event.localPosition.dx),
            onExit: (_) => setState(() => _markerX = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  setState(() => _markerX = details.localPosition.dx),
              onHorizontalDragUpdate: (details) =>
                  setState(() => _markerX = details.localPosition.dx),
              // A finger has no hover to leave by, so the marker goes with it.
              onTapUp: (_) => setState(() => _markerX = null),
              onTapCancel: () => setState(() => _markerX = null),
              onHorizontalDragEnd: (_) => setState(() => _markerX = null),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MetricDayPainter(
                        readings: widget.readings,
                        hourly: hourly,
                        color: widget.color,
                        unit: widget.unit,
                        sum: widget.sum,
                        markerX: _markerX,
                        gridColor: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                        labelColor: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                  if (marker != null)
                    Positioned(
                      left: (_markerX! - 52).clamp(
                        0.0,
                        math.max(0, constraints.maxWidth - 104),
                      ),
                      top: 0,
                      child: HealthChartTooltip(
                        title: marker.time,
                        readings: [
                          (
                            color: widget.color,
                            text: healthMetricValue(marker.value, widget.unit),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// What sits under the marker: the hour's total for bars, the closest reading
  /// for a curve.
  ({String time, double value})? _readingAt(
    double width,
    List<double?>? hourly,
  ) {
    final plotWidth = width - _plotLeft - _plotRightInset;
    if (plotWidth <= 0) return null;
    final ratio = ((_markerX! - _plotLeft) / plotWidth).clamp(0.0, 1.0);
    if (hourly != null) {
      final hour = (ratio * 24).floor().clamp(0, 23);
      final value = hourly[hour];
      if (value == null) return null;
      return (time: '${_two(hour)}:00', value: value);
    }
    final minuteOfDay = (ratio * Duration.minutesPerDay).round();
    final nearest = widget.readings.reduce((closest, candidate) {
      return (_minuteOfDay(candidate) - minuteOfDay).abs() <
              (_minuteOfDay(closest) - minuteOfDay).abs()
          ? candidate
          : closest;
    });
    final date = DateTime.fromMillisecondsSinceEpoch(nearest.t);
    return (time: '${_two(date.hour)}:${_two(date.minute)}', value: nearest.v);
  }

  static int _minuteOfDay(HealthDayReading reading) {
    final date = DateTime.fromMillisecondsSinceEpoch(reading.t);
    return date.hour * 60 + date.minute;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _DayStats extends StatelessWidget {
  final List<HealthDayReading> readings;
  final String unit;
  final Color color;
  final bool sum;

  const _DayStats({
    required this.readings,
    required this.unit,
    required this.color,
    required this.sum,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = [for (final reading in readings) reading.v];
    final total = values.reduce((a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            if (sum)
              HealthRecordStatItem(
                icon: Icons.functions_rounded,
                color: color,
                label: l10n.healthDashboardDayTotal,
                value: healthMetricValue(total, unit),
              ),
            HealthRecordStatItem(
              icon: Icons.show_chart_rounded,
              color: color,
              label: l10n.healthDashboardDayAvg,
              value: healthMetricValue(total / values.length, unit),
            ),
            HealthRecordStatItem(
              icon: Icons.arrow_downward_rounded,
              color: color,
              label: l10n.healthDashboardDayMin,
              value: healthMetricValue(values.reduce(math.min), unit),
            ),
            HealthRecordStatItem(
              icon: Icons.arrow_upward_rounded,
              color: color,
              label: l10n.healthDashboardDayMax,
              value: healthMetricValue(values.reduce(math.max), unit),
            ),
            HealthRecordStatItem(
              icon: Icons.timeline_rounded,
              color: color,
              label: l10n.healthDashboardCount,
              value: healthValue(values.length, 'count'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricDayPainter extends CustomPainter {
  final List<HealthDayReading> readings;

  /// Per-hour totals, set only for metrics drawn as bars.
  final List<double?>? hourly;
  final Color color;
  final String unit;
  final bool sum;
  final double? markerX;
  final Color gridColor;
  final Color labelColor;

  const _MetricDayPainter({
    required this.readings,
    required this.hourly,
    required this.color,
    required this.unit,
    required this.sum,
    required this.markerX,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(34, 14, size.width - 48, size.height - 46);
    final buckets = hourly;
    final drawn = buckets == null
        ? [for (final reading in readings) reading.v]
        : buckets.whereType<double>().toList();
    if (drawn.isEmpty) return;
    final min = drawn.reduce(math.min);
    final max = drawn.reduce(math.max);
    final padding = math.max((max - min) * .15, 1).toDouble();
    final lower = sum ? 0.0 : math.max(0.0, min - padding);
    final upper = math.max(lower + 1, max + padding);
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = plot.top + plot.height * index / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(
        canvas,
        healthAxisNumber(lower + (upper - lower) * (2 - index) / 2, unit),
        Offset(plot.left - 5, y - 6),
        right: true,
      );
    }
    if (markerX != null) {
      final x = markerX!.clamp(plot.left, plot.right);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = labelColor
          ..strokeWidth = 1,
      );
    }
    if (buckets == null) {
      _paintCurve(canvas, plot, lower, upper);
    } else {
      _paintBars(canvas, plot, buckets, lower, upper);
    }
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

  void _paintCurve(Canvas canvas, Rect plot, double lower, double upper) {
    final points = <Offset>[];
    for (final reading in readings) {
      final date = DateTime.fromMillisecondsSinceEpoch(reading.t);
      final x = plot.left + plot.width * (date.hour * 60 + date.minute) / 1440;
      final y =
          plot.bottom - (reading.v - lower) / (upper - lower) * plot.height;
      points.add(Offset(x, y));
    }
    canvas.drawPath(
      _smoothPath(points),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    // A dense series - a day of heart rate is hundreds of samples - turns into a
    // solid band of dots, so markers only go on a curve sparse enough to read.
    if (points.length > 48) return;
    for (final point in points) {
      canvas.drawCircle(point, 3.5, Paint()..color = color);
    }
  }

  void _paintBars(
    Canvas canvas,
    Rect plot,
    List<double?> buckets,
    double lower,
    double upper,
  ) {
    final width = plot.width / buckets.length * 0.62;
    for (var hour = 0; hour < buckets.length; hour++) {
      final value = buckets[hour];
      if (value == null) continue;
      final height = (value - lower) / (upper - lower) * plot.height;
      final x = plot.left + plot.width * (hour + 0.5) / buckets.length;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - width / 2, plot.bottom - height, width, height),
          const Radius.circular(4),
        ),
        Paint()..color = color,
      );
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
      oldDelegate.hourly != hourly ||
      oldDelegate.color != color ||
      oldDelegate.markerX != markerX ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor;
}
