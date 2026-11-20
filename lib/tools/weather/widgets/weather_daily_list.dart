import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/daily_forecast.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';
import 'weather_icon_view.dart';

class WeatherDailyList extends StatelessWidget {
  const WeatherDailyList({
    super.key,
    required this.days,
    required this.units,
    required this.currentTemperature,
    required this.onDayTap,
  });

  final List<DailyForecast> days;
  final WeatherUnits units;
  final double? currentTemperature;
  final ValueChanged<DailyForecast> onDayTap;

  @override
  Widget build(BuildContext context) {
    final mins = days.map((d) => d.minTemperature).nonNulls;
    final maxs = days.map((d) => d.maxTemperature).nonNulls;
    if (mins.isEmpty || maxs.isEmpty) return const SizedBox.shrink();
    final low = mins.reduce(math.min);
    final high = maxs.reduce(math.max);
    final today = DateTime.now();
    return Column(
      children: [
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const Divider(height: 1),
          _DayRow(
            day: day,
            units: units,
            low: low,
            high: high,
            marker: isSameDay(day.date, today) ? currentTemperature : null,
            onTap: () => onDayTap(day),
          ),
        ],
      ],
    );
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.units,
    required this.low,
    required this.high,
    required this.marker,
    required this.onTap,
  });

  final DailyForecast day;
  final WeatherUnits units;
  final double low;
  final double high;
  final double? marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final label = WeatherDailyList.isSameDay(day.date, now)
        ? l10n.weatherToday
        : WeatherDailyList.isSameDay(day.date, tomorrow)
        ? l10n.weatherTomorrow
        : format.weekdayShort(day.date);
    final prob = day.precipitationProbability;
    final bold = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final cramped = constraints.maxWidth < 300;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(label, maxLines: 1, style: bold),
                      ),
                      Text(
                        format.dayMonth(day.date),
                        maxLines: 1,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                WeatherIconView(
                  condition: day.condition,
                  isDay: true,
                  size: 34,
                ),
                if (!cramped)
                  SizedBox(
                    width: 42,
                    child: prob != null && prob >= 10
                        ? Text(
                            '${prob.round()}%',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: WeatherColors.precipitationBar,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                SizedBox(
                  width: 36,
                  child: Text(
                    units.temperatureText(day.minTemperature),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    style: muted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 8,
                    child: CustomPaint(
                      painter: _RangeBarPainter(
                        low: low,
                        high: high,
                        min: day.minTemperature ?? low,
                        max: day.maxTemperature ?? high,
                        marker: marker,
                        track: theme.colorScheme.surfaceContainerHighest,
                        markerColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    units.temperatureText(day.maxTemperature),
                    maxLines: 1,
                    style: bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  _RangeBarPainter({
    required this.low,
    required this.high,
    required this.min,
    required this.max,
    required this.marker,
    required this.track,
    required this.markerColor,
  });

  final double low;
  final double high;
  final double min;
  final double max;
  final double? marker;
  final Color track;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = track,
    );
    final span = math.max(high - low, 1.0);
    double x(double t) => ((t - low) / span).clamp(0.0, 1.0) * size.width;
    final rect = Rect.fromLTRB(
      x(min),
      0,
      math.max(x(max), x(min) + size.height),
      size.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, r),
      Paint()
        ..shader = LinearGradient(
          colors: [
            WeatherColors.temperature(min),
            WeatherColors.temperature(max),
          ],
        ).createShader(rect),
    );
    final m = marker;
    if (m != null) {
      final c = Offset(x(m), size.height / 2);
      canvas.drawCircle(c, size.height * .75, Paint()..color = track);
      canvas.drawCircle(c, size.height * .5, Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(_RangeBarPainter old) =>
      old.min != min ||
      old.max != max ||
      old.low != low ||
      old.high != high ||
      old.marker != marker;
}
