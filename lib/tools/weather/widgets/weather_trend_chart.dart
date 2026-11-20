import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/hourly_forecast.dart';
import '../weather_colors.dart';
import '../weather_units.dart';

enum WeatherTrendMetric { temperature, precipitation, wind, pressure }

class WeatherTrendChart extends StatelessWidget {
  const WeatherTrendChart({
    super.key,
    required this.hours,
    required this.metric,
    required this.units,
    required this.dayLabel,
    this.height = 200,
  });

  final List<HourlyForecast> hours;
  final WeatherTrendMetric metric;
  final WeatherUnits units;

  /// Label below a day boundary, or the hour label for single-day charts.
  final String Function(DateTime localTime) dayLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendPainter(
          hours: hours,
          metric: metric,
          units: units,
          dayLabel: dayLabel,
          axisStyle: theme.textTheme.labelSmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          gridColor: theme.dividerColor.withValues(alpha: .5),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.hours,
    required this.metric,
    required this.units,
    required this.dayLabel,
    required this.axisStyle,
    required this.gridColor,
  });

  final List<HourlyForecast> hours;
  final WeatherTrendMetric metric;
  final WeatherUnits units;
  final String Function(DateTime localTime) dayLabel;
  final TextStyle axisStyle;
  final Color gridColor;

  static const double _left = 40;
  static const double _bottom = 20;

  double? _value(HourlyForecast h) => switch (metric) {
    WeatherTrendMetric.temperature =>
      h.temperature == null ? null : units.temperature(h.temperature!),
    WeatherTrendMetric.precipitation => h.precipitation,
    WeatherTrendMetric.wind =>
      h.windSpeed == null ? null : units.wind(h.windSpeed!),
    WeatherTrendMetric.pressure => h.pressure,
  };

  double? _secondary(HourlyForecast h) => switch (metric) {
    WeatherTrendMetric.wind =>
      h.windGust == null ? null : units.wind(h.windGust!),
    _ => null,
  };

  Color get _color => switch (metric) {
    WeatherTrendMetric.temperature => WeatherColors.temperatureLine,
    WeatherTrendMetric.precipitation => WeatherColors.precipitationBar,
    WeatherTrendMetric.wind => WeatherColors.windLine,
    WeatherTrendMetric.pressure => WeatherColors.pressureLine,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.length < 2) return;
    final values = [for (final h in hours) _value(h)];
    final extra = [for (final h in hours) _secondary(h)];
    final all = [...values.nonNulls, ...extra.nonNulls];
    if (all.isEmpty) return;
    var lo = all.reduce(math.min);
    var hi = all.reduce(math.max);
    if (metric == WeatherTrendMetric.precipitation ||
        metric == WeatherTrendMetric.wind) {
      lo = 0;
    }
    if (metric == WeatherTrendMetric.precipitation) hi = math.max(hi, 1);
    final pad = math.max(
      (hi - lo) * .12,
      metric == WeatherTrendMetric.pressure ? 2.0 : 1.0,
    );
    if (metric != WeatherTrendMetric.precipitation &&
        metric != WeatherTrendMetric.wind) {
      lo -= pad;
    }
    hi += pad;

    final plot = Rect.fromLTRB(_left, 8, size.width - 4, size.height - _bottom);
    final start = hours.first.time.millisecondsSinceEpoch.toDouble();
    final end = hours.last.time.millisecondsSinceEpoch.toDouble();
    double x(DateTime t) =>
        plot.left +
        (t.millisecondsSinceEpoch - start) / (end - start) * plot.width;
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = lo + (hi - lo) * i / 3;
      final dy = y(v);
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), grid);
      _text(canvas, _axis(v), Offset(plot.left - 6, dy - 7), right: true);
    }

    final single =
        hours.last.time.difference(hours.first.time) <=
        const Duration(hours: 26);
    for (final h in hours) {
      final local = h.time.toLocal();
      final mark = single ? local.hour % 3 == 0 : local.hour == 0;
      if (!mark) continue;
      final dx = x(h.time);
      canvas.drawLine(Offset(dx, plot.top), Offset(dx, plot.bottom), grid);
      _text(
        canvas,
        dayLabel(local),
        Offset(dx + (single ? 0 : 4), plot.bottom + 4),
        center: single,
      );
    }

    final nowX = x(DateTime.now());
    if (nowX > plot.left && nowX < plot.right) {
      canvas.drawLine(
        Offset(nowX, plot.top),
        Offset(nowX, plot.bottom),
        Paint()
          ..color = _color.withValues(alpha: .7)
          ..strokeWidth = 1.5,
      );
    }

    if (metric == WeatherTrendMetric.precipitation) {
      final w = math.max(1.5, plot.width / hours.length * .7);
      for (var i = 0; i < hours.length; i++) {
        final v = values[i];
        if (v == null || v <= 0) continue;
        final prob = hours[i].precipitationProbability ?? 100;
        final dx = x(hours[i].time);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(dx - w / 2, y(v), dx + w / 2, plot.bottom),
            Radius.circular(w / 3),
          ),
          Paint()..color = _color.withValues(alpha: .35 + .65 * prob / 100),
        );
      }
      return;
    }

    if (metric == WeatherTrendMetric.wind) {
      _line(
        canvas,
        extra,
        x,
        y,
        plot,
        _color.withValues(alpha: .45),
        fill: false,
        dashed: true,
      );
    }
    _line(canvas, values, x, y, plot, _color, fill: true);
  }

  void _line(
    Canvas canvas,
    List<double?> values,
    double Function(DateTime) x,
    double Function(double) y,
    Rect plot,
    Color color, {
    required bool fill,
    bool dashed = false,
  }) {
    final path = Path();
    var started = false;
    for (var i = 0; i < hours.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final p = Offset(x(hours[i].time), y(v));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (!started) return;
    if (fill) {
      final bounds = path.getBounds();
      final area = Path.from(path)
        ..lineTo(bounds.right, plot.bottom)
        ..lineTo(bounds.left, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .35), color.withValues(alpha: 0)],
          ).createShader(plot),
      );
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 1.5 : 2.5
      ..strokeJoin = StrokeJoin.round;
    if (!dashed) {
      canvas.drawPath(path, stroke);
      return;
    }
    for (final metricPath in path.computeMetrics()) {
      for (var d = 0.0; d < metricPath.length; d += 8) {
        canvas.drawPath(metricPath.extractPath(d, d + 4), stroke);
      }
    }
  }

  String _axis(double v) => switch (metric) {
    WeatherTrendMetric.temperature => '${v.round()}°',
    WeatherTrendMetric.precipitation => v.toStringAsFixed(v < 2 ? 1 : 0),
    WeatherTrendMetric.wind => '${v.round()}',
    WeatherTrendMetric.pressure => '${v.round()}',
  };

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool right = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: axisStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right
        ? at.dx - tp.width
        : (center ? at.dx - tp.width / 2 : at.dx);
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.hours != hours ||
      old.metric != metric ||
      old.units.settings != units.settings;
}
