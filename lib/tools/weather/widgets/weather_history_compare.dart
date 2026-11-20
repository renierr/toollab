import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/weather_history_summary.dart';
import '../weather_units.dart';
import 'weather_section_card.dart';

/// The same period a year earlier, shown once enough of it was recorded.
class WeatherHistoryCompare extends StatelessWidget {
  const WeatherHistoryCompare({
    super.key,
    required this.current,
    required this.previous,
    required this.units,
  });

  /// Below this share of recorded hours a comparison would mislead.
  static const double minCoverage = .5;

  final HistorySummary current;
  final HistorySummary previous;
  final WeatherUnits units;

  static bool isMeaningful(
    HistorySummary current,
    HistorySummary previous,
    DateTime now,
  ) =>
      current.coverage(now) >= minCoverage &&
      previous.coverage(now) >= minCoverage &&
      current.total.meanTemperature != null &&
      previous.total.meanTemperature != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final diff =
        units.temperature(current.total.meanTemperature!) -
        units.temperature(previous.total.meanTemperature!);
    final rounded = (diff * 10).round() / 10;
    final value = '${rounded.abs().toStringAsFixed(1)}°';
    final temperature = rounded == 0
        ? l10n.weatherHistorySameTemperature
        : (rounded > 0
              ? l10n.weatherHistoryWarmer(value)
              : l10n.weatherHistoryColder(value));
    final rainDiff = current.total.precipitation - previous.total.precipitation;
    final rain = units.precipitationText(rainDiff.abs());
    return WeatherSectionCard(
      title: l10n.weatherHistoryCompare('${previous.range.start.year}'),
      icon: Icons.compare_arrows,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(
            icon: rounded >= 0 ? Icons.trending_up : Icons.trending_down,
            text: temperature,
          ),
          const SizedBox(height: 8),
          _Line(
            icon: Icons.umbrella_outlined,
            text: rainDiff >= 0
                ? l10n.weatherHistoryMoreRain(rain)
                : l10n.weatherHistoryLessRain(rain),
          ),
          const SizedBox(height: 8),
          Text(
            '${units.temperatureText(previous.total.meanTemperature)} · '
            '${units.precipitationText(previous.total.precipitation)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}
