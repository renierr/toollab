import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/weather_condition.dart';
import '../weather_device_location.dart';
import 'weather_icon_view.dart';
import 'weather_location_actions.dart';

class WeatherEmptyState extends StatelessWidget {
  const WeatherEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WeatherIconView(
                condition: WeatherCondition.partlyCloudy,
                isDay: true,
                size: 140,
                animate: true,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.weatherEmptyTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l10n.weatherEmptyMessage, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.search),
                    label: Text(l10n.weatherAddPlace),
                    onPressed: () => WeatherLocationActions.addPlace(context),
                  ),
                  if (WeatherDeviceLocation.isSupported)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: Text(l10n.weatherUseMyLocation),
                      onPressed: () =>
                          WeatherLocationActions.addDeviceLocation(context),
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
