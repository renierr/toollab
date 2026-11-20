import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/hourly_forecast.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';
import 'weather_icon_view.dart';

class WeatherHourlyStrip extends StatelessWidget {
  const WeatherHourlyStrip({
    super.key,
    required this.hours,
    required this.isDayAt,
    required this.units,
  });

  static const double _itemWidth = 58;
  static const double _height = 196;

  final List<HourlyForecast> hours;
  final bool Function(DateTime time) isDayAt;
  final WeatherUnits units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    return SizedBox(
      height: _height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: hours.length * _itemWidth,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HourlyCurvePainter(
                    hours: hours,
                    units: units,
                    itemWidth: _itemWidth,
                    labelStyle: theme.textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    smallStyle: theme.textTheme.labelSmall!.copyWith(
                      color: WeatherColors.precipitationBar,
                    ),
                    dayStyle: theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    dayLabels: {
                      for (var i = 1; i < hours.length; i++)
                        if (hours[i].time.toLocal().hour == 0)
                          i: format.weekdayShort(hours[i].time.toLocal()),
                    },
                    gridColor: theme.dividerColor,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < hours.length; i++)
                    SizedBox(
                      width: _itemWidth,
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            i == 0
                                ? l10n.weatherNow
                                : format.time(hours[i].time),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: i == 0 ? FontWeight.w800 : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          WeatherIconView(
                            condition: hours[i].condition,
                            isDay: isDayAt(hours[i].time),
                            size: 34,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourlyCurvePainter extends CustomPainter {
  _HourlyCurvePainter({
    required this.hours,
    required this.units,
    required this.itemWidth,
    required this.labelStyle,
    required this.smallStyle,
    required this.dayStyle,
    required this.dayLabels,
    required this.gridColor,
  });

  final List<HourlyForecast> hours;
  final WeatherUnits units;
  final double itemWidth;
  final TextStyle labelStyle;
  final TextStyle smallStyle;
  final TextStyle dayStyle;
  final Map<int, String> dayLabels;
  final Color gridColor;

  static const double _curveTop = 84;
  static const double _curveBottom = 118;
  static const double _barBottom = 158;
  static const double _barMax = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final temps = [for (final h in hours) h.temperature];
    final known = temps.nonNulls.toList();
    if (known.isEmpty) return;
    final lo = known.reduce(math.min);
    final hi = known.reduce(math.max);
    final span = math.max(hi - lo, 1.0);
    double x(int i) => i * itemWidth + itemWidth / 2;
    double y(double t) =>
        _curveBottom - (t - lo) / span * (_curveBottom - _curveTop);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final entry in dayLabels.entries) {
      final dx = entry.key * itemWidth;
      for (var dy = 4.0; dy < size.height - 4; dy += 8) {
        canvas.drawLine(Offset(dx, dy), Offset(dx, dy + 4), grid);
      }
      _text(
        canvas,
        entry.value,
        dayStyle,
        Offset(dx + 4, size.height - 14),
        align: TextAlign.left,
      );
    }

    final points = <Offset>[
      for (var i = 0; i < hours.length; i++)
        if (temps[i] != null) Offset(x(i), y(temps[i]!)),
    ];
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final mid = (p0.dx + p1.dx) / 2;
        path.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
      }
      final fill = Path.from(path)
        ..lineTo(points.last.dx, _curveBottom + 18)
        ..lineTo(points.first.dx, _curveBottom + 18)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  WeatherColors.temperatureLine.withValues(alpha: .28),
                  WeatherColors.temperatureLine.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromLTRB(0, _curveTop, size.width, _curveBottom + 18),
              ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              for (final t in known.take(math.min(known.length, 12)))
                WeatherColors.temperature(t),
            ],
          ).createShader(Rect.fromLTRB(0, 0, size.width, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < hours.length; i++) {
      final t = temps[i];
      if (t != null) {
        final p = Offset(x(i), y(t));
        canvas.drawCircle(
          p,
          3.5,
          Paint()..color = WeatherColors.temperature(t),
        );
        _text(
          canvas,
          units.temperatureText(t),
          labelStyle,
          p.translate(0, -22),
        );
      }
      final rain = hours[i].precipitation ?? 0;
      final prob = hours[i].precipitationProbability;
      if (rain > 0.05) {
        final h = math.min(_barMax, 6 + math.sqrt(rain) * 14);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x(i) - 9, _barBottom - h, 18, h),
          const Radius.circular(5),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = WeatherColors.precipitationBar.withValues(
              alpha: .35 + math.min(.6, rain / 4),
            ),
        );
      }
      if (prob != null && prob >= 10) {
        _text(
          canvas,
          '${prob.round()}%',
          smallStyle,
          Offset(x(i), _barBottom + 2),
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    TextAlign align = TextAlign.center,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == TextAlign.center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_HourlyCurvePainter old) =>
      old.hours != hours ||
      old.units.settings != units.settings ||
      old.labelStyle != labelStyle;
}
