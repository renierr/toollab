import 'dart:math' as math;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/health_chart_tooltip.dart';

import '../models/hourly_forecast.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';

enum WeatherTrendMetric { temperature, precipitation, wind, pressure }

class WeatherTrendChart extends StatefulWidget {
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
  State<WeatherTrendChart> createState() => _WeatherTrendChartState();
}

class _WeatherTrendChartState extends State<WeatherTrendChart>
    with DisposeCleanup {
  /// Touch has no "leave" event, so the readout hides itself.
  static const Duration _touchLinger = Duration(seconds: 3);
  static const Duration _mouseLinger = Duration(seconds: 6);

  int? _selected;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    onDispose(() => _hideTimer?.cancel());
  }

  void _select(Offset local, double width, {required bool touch}) {
    final hours = widget.hours;
    if (hours.length < 2) return;
    final t =
        ((local.dx - _TrendPainter.left) /
                (width - _TrendPainter.left - _TrendPainter.right))
            .clamp(0.0, 1.0);
    final start = hours.first.time.millisecondsSinceEpoch;
    final target = start + t * (hours.last.time.millisecondsSinceEpoch - start);
    var best = 0;
    for (var i = 1; i < hours.length; i++) {
      if ((hours[i].time.millisecondsSinceEpoch - target).abs() <
          (hours[best].time.millisecondsSinceEpoch - target).abs()) {
        best = i;
      }
    }
    if (best != _selected) setState(() => _selected = best);
    _hideTimer?.cancel();
    _hideTimer = Timer(touch ? _touchLinger : _mouseLinger, _clear);
  }

  void _clear() {
    _hideTimer?.cancel();
    if (mounted && _selected != null) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final hour = selected == null || selected >= widget.hours.length
              ? null
              : widget.hours[selected];
          final x = hour == null
              ? 0.0
              : _TrendPainter.xFor(widget.hours, hour.time, width);
          return MouseRegion(
            onHover: (e) => _select(e.localPosition, width, touch: false),
            onExit: (_) => _clear(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition, width, touch: true),
              onHorizontalDragStart: (d) =>
                  _select(d.localPosition, width, touch: true),
              onHorizontalDragUpdate: (d) =>
                  _select(d.localPosition, width, touch: true),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TrendPainter(
                        hours: widget.hours,
                        metric: widget.metric,
                        units: widget.units,
                        dayLabel: widget.dayLabel,
                        selected: selected,
                        axisStyle: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        gridColor: theme.dividerColor.withValues(alpha: .5),
                        cursorColor: theme.colorScheme.onSurface.withValues(
                          alpha: .5,
                        ),
                      ),
                    ),
                  ),
                  if (hour != null)
                    Positioned(
                      top: 4,
                      left: x < width / 2 ? x + 12 : null,
                      right: x >= width / 2 ? width - x + 12 : null,
                      child: IgnorePointer(
                        child: ConstrainedBox(
                          // The side of the cursor it sits on, so long
                          // lines wrap instead of running off the chart.
                          constraints: BoxConstraints(
                            maxWidth: (x < width / 2 ? width - x : x) - 16,
                          ),
                          child: _HourReadout(hour: hour, units: widget.units),
                        ),
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
}

class _HourReadout extends StatelessWidget {
  const _HourReadout({required this.hour, required this.units});

  final HourlyForecast hour;
  final WeatherUnits units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = WeatherTimeFormat(context);
    final rain = hour.precipitation;
    final prob = hour.precipitationProbability;
    final direction = hour.windDirection;
    return HealthChartTooltip(
      title: '${format.dayTime(hour.time)} · ${hour.condition.label(l10n)}',
      readings: [
        if (hour.temperature != null)
          (
            color: WeatherColors.temperature(hour.temperature!),
            text:
                '${l10n.weatherTemperature} ${units.temperatureText(hour.temperature)}',
          ),
        if (rain != null || prob != null)
          (
            color: WeatherColors.precipitationBar,
            text: [
              '${l10n.weatherPrecipitation} ${units.precipitationText(rain ?? 0)}',
              if (prob != null) WeatherUnits.percentText(prob),
            ].join(' · '),
          ),
        if (hour.windSpeed != null)
          (
            color: WeatherColors.windLine,
            text: [
              '${l10n.weatherWind} ${units.windText(hour.windSpeed)}',
              if (direction != null) WeatherL10n.direction(l10n, direction),
              if (hour.windGust != null)
                l10n.weatherGusts(units.windText(hour.windGust)),
            ].join(' · '),
          ),
        if (hour.pressure != null)
          (
            color: WeatherColors.pressureLine,
            text:
                '${l10n.weatherPressure} ${units.pressureText(hour.pressure)}',
          ),
        if (hour.humidity != null)
          (
            color: WeatherColors.rain,
            text:
                '${l10n.weatherHumidity} ${WeatherUnits.percentText(hour.humidity)}',
          ),
        if (hour.cloudCover != null)
          (
            color: WeatherColors.cloudDark,
            text:
                '${l10n.weatherCloudCover} ${WeatherUnits.percentText(hour.cloudCover)}',
          ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.hours,
    required this.metric,
    required this.units,
    required this.dayLabel,
    required this.selected,
    required this.axisStyle,
    required this.gridColor,
    required this.cursorColor,
  });

  final List<HourlyForecast> hours;
  final WeatherTrendMetric metric;
  final WeatherUnits units;
  final String Function(DateTime localTime) dayLabel;
  final int? selected;
  final TextStyle axisStyle;
  final Color gridColor;
  final Color cursorColor;

  static const double left = 40;
  static const double right = 4;
  static const double _bottom = 20;

  static double xFor(List<HourlyForecast> hours, DateTime t, double width) {
    final start = hours.first.time.millisecondsSinceEpoch.toDouble();
    final end = hours.last.time.millisecondsSinceEpoch.toDouble();
    return left +
        (t.millisecondsSinceEpoch - start) /
            (end - start) *
            (width - left - right);
  }

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
    _paintChart(canvas, size);
    final i = selected;
    if (i == null || i >= hours.length || hours.length < 2) return;
    final x = xFor(hours, hours[i].time, size.width);
    canvas.drawLine(
      Offset(x, 8),
      Offset(x, size.height - _bottom),
      Paint()
        ..color = cursorColor
        ..strokeWidth = 1.5,
    );
    final v = _value(hours[i]);
    final y = _lastY;
    if (v != null && y != null) {
      final py = y(v);
      canvas.drawCircle(Offset(x, py), 6, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, py), 4, Paint()..color = _color);
    }
  }

  double Function(double v)? _lastY;

  void _paintChart(Canvas canvas, Size size) {
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

    final plot = Rect.fromLTRB(
      left,
      8,
      size.width - right,
      size.height - _bottom,
    );
    final start = hours.first.time.millisecondsSinceEpoch.toDouble();
    final end = hours.last.time.millisecondsSinceEpoch.toDouble();
    double x(DateTime t) =>
        plot.left +
        (t.millisecondsSinceEpoch - start) / (end - start) * plot.width;
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;
    _lastY = y;

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
