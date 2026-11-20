import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/daily_forecast.dart';
import '../models/weather_snapshot.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';
import 'weather_icon_view.dart';

class WeatherHero extends StatelessWidget {
  const WeatherHero({
    super.key,
    required this.name,
    required this.current,
    required this.today,
    required this.isDay,
    required this.units,
    required this.animate,
    required this.observationStation,
  });

  final String name;
  final CurrentConditions current;
  final DailyForecast? today;
  final bool isDay;
  final WeatherUnits units;
  final bool animate;
  final String? observationStation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final colors = WeatherColors.sky(current.condition, isDay: isDay);
    final measuredAt = current.measuredAt;
    final today = this.today;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cramped = constraints.maxWidth < 380;
        final iconSize = cramped ? 96.0 : 132.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: .25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              cramped ? 18 : 24,
              20,
              cramped ? 12 : 20,
              20,
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                units.temperatureText(current.temperature),
                                style: TextStyle(
                                  fontSize: cramped ? 64 : 84,
                                  fontWeight: FontWeight.w300,
                                  height: 1.05,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              current.condition.label(l10n),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      WeatherIconView(
                        condition: current.condition,
                        isDay: isDay,
                        size: iconSize,
                        animate: animate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (current.feelsLike != null)
                        Text(
                          l10n.weatherFeelsLike(
                            units.temperatureText(current.feelsLike),
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      if (today != null)
                        _HighLow(
                          high: units.temperatureText(today.maxTemperature),
                          low: units.temperatureText(today.minTemperature),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SourceChip(
                    icon: measuredAt != null ? Icons.sensors : Icons.auto_graph,
                    label: measuredAt != null
                        ? l10n.weatherMeasuredAt(
                            format.time(measuredAt),
                            observationStation ?? '',
                          )
                        : l10n.weatherForecastValue,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighLow extends StatelessWidget {
  const _HighLow({required this.high, required this.low});

  final String high;
  final String low;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white70);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.arrow_upward, size: 14, color: Colors.white70),
        Text(high, style: style),
        const SizedBox(width: 10),
        const Icon(Icons.arrow_downward, size: 14, color: Colors.white70),
        Text(low, style: style),
      ],
    );
  }
}
