import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/hourly_forecast.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';
import 'weather_section_card.dart';
import 'weather_trend_chart.dart';

class WeatherTrendCard extends StatefulWidget {
  const WeatherTrendCard({super.key, required this.hours, required this.units});

  final List<HourlyForecast> hours;
  final WeatherUnits units;

  @override
  State<WeatherTrendCard> createState() => _WeatherTrendCardState();
}

class _WeatherTrendCardState extends State<WeatherTrendCard> {
  WeatherTrendMetric _metric = WeatherTrendMetric.temperature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = WeatherTimeFormat(context);
    return WeatherSectionCard(
      title: l10n.weatherTrend,
      icon: Icons.show_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<WeatherTrendMetric>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: WeatherTrendMetric.temperature,
                  icon: const Icon(Icons.thermostat, size: 18),
                  label: Text(l10n.weatherTemperature),
                ),
                ButtonSegment(
                  value: WeatherTrendMetric.precipitation,
                  icon: const Icon(Icons.umbrella_outlined, size: 18),
                  label: Text(l10n.weatherPrecipitation),
                ),
                ButtonSegment(
                  value: WeatherTrendMetric.wind,
                  icon: const Icon(Icons.air, size: 18),
                  label: Text(l10n.weatherWind),
                ),
                ButtonSegment(
                  value: WeatherTrendMetric.pressure,
                  icon: const Icon(Icons.speed, size: 18),
                  label: Text(l10n.weatherPressure),
                ),
              ],
              selected: {_metric},
              onSelectionChanged: (s) => setState(() => _metric = s.first),
            ),
          ),
          const SizedBox(height: 12),
          WeatherTrendChart(
            hours: widget.hours,
            metric: _metric,
            units: widget.units,
            dayLabel: format.weekdayShort,
          ),
        ],
      ),
    );
  }
}
