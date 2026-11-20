import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/daily_forecast.dart';
import '../models/weather_snapshot.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';
import 'weather_hourly_strip.dart';
import 'weather_icon_view.dart';
import 'weather_trend_chart.dart';

class WeatherDaySheet extends StatelessWidget {
  const WeatherDaySheet({
    super.key,
    required this.day,
    required this.snapshot,
    required this.units,
  });

  final DailyForecast day;
  final WeatherSnapshot snapshot;
  final WeatherUnits units;

  static Future<void> show(
    BuildContext context, {
    required DailyForecast day,
    required WeatherSnapshot snapshot,
    required WeatherUnits units,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => WeatherDaySheet(day: day, snapshot: snapshot, units: units),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final sun = snapshot.sunTimes(day.date);
    final facts = <(IconData, String)>[
      (
        Icons.thermostat,
        '${units.temperatureText(day.maxTemperature)} / ${units.temperatureText(day.minTemperature)}',
      ),
      (Icons.umbrella_outlined, units.precipitationText(day.precipitationSum)),
      if (day.precipitationProbability != null)
        (
          Icons.water_drop_outlined,
          WeatherUnits.percentText(day.precipitationProbability),
        ),
      if (day.maxWindGust != null)
        (Icons.air, l10n.weatherGusts(units.windText(day.maxWindGust))),
      if (day.sunshineHours != null)
        (
          Icons.wb_sunny_outlined,
          l10n.weatherSunshineHours(day.sunshineHours!.toStringAsFixed(1)),
        ),
      if (sun.sunrise != null && sun.sunset != null)
        (
          Icons.wb_twilight,
          '${format.time(sun.sunrise!)} – ${format.time(sun.sunset!)}',
        ),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              WeatherIconView(
                condition: day.condition,
                isDay: true,
                size: 64,
                animate: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format.weekdayDate(day.date),
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      day.condition.label(l10n),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, text) in facts)
                Chip(
                  avatar: Icon(icon, size: 18),
                  label: Text(text),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.weatherDayDetails, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          WeatherHourlyStrip(
            hours: day.hours,
            isDayAt: snapshot.isDayAt,
            units: units,
          ),
          const SizedBox(height: 12),
          Text(l10n.weatherTemperature, style: theme.textTheme.titleSmall),
          WeatherTrendChart(
            hours: day.hours,
            metric: WeatherTrendMetric.temperature,
            units: units,
            dayLabel: format.hour,
            height: 160,
          ),
          const SizedBox(height: 12),
          Text(l10n.weatherPrecipitation, style: theme.textTheme.titleSmall),
          WeatherTrendChart(
            hours: day.hours,
            metric: WeatherTrendMetric.precipitation,
            units: units,
            dayLabel: format.hour,
            height: 120,
          ),
        ],
      ),
    );
  }
}
