import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../api/station_catalog.dart';
import '../models/weather_snapshot.dart';
import '../weather_l10n.dart';

class WeatherSourceFooter extends StatelessWidget {
  const WeatherSourceFooter({super.key, required this.snapshot});

  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = WeatherTimeFormat(context);
    final forecast = snapshot.forecastStation;
    final observation = snapshot.observationStation;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String station(StationMatch match) => match.station.isLocal
        ? l10n.weatherSourceLocal(match.station.name)
        : '${match.station.name} '
              '(${match.distanceKm.toStringAsFixed(match.distanceKm < 10 ? 1 : 0)} km)';
    return Column(
      children: [
        if (snapshot.isStale)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.weatherOffline,
                    style: style?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        Text(
          [
            l10n.weatherUpdated(format.time(snapshot.fetchedAt)),
            if (forecast != null) l10n.weatherSourceForecast(station(forecast)),
            if (observation != null)
              l10n.weatherSourceObservation(station(observation)),
          ].join(' · '),
          style: style,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.weatherSourceAttribution,
          style: style,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
