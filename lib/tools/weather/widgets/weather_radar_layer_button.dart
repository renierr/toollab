import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../weather_settings.dart';
import '../weather_state.dart';

class WeatherRadarLayerButton extends StatelessWidget {
  const WeatherRadarLayerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<WeatherState>();
    final s = state.settings;
    return PopupMenuButton<String>(
      tooltip: l10n.weatherRadarLayers,
      icon: const Icon(Icons.layers_outlined),
      onSelected: (v) {
        final next = switch (v) {
          'light' => s.copyWith(radarBaseMap: RadarBaseMap.light),
          'dark' => s.copyWith(radarBaseMap: RadarBaseMap.dark),
          'satellite' => s.copyWith(radarBaseMap: RadarBaseMap.satellite),
          'lightning' => s.copyWith(radarLightning: !s.radarLightning),
          _ => s.copyWith(radarWarnings: !s.radarWarnings),
        };
        state.updateSettings(next);
      },
      itemBuilder: (context) => [
        for (final (value, mode, label) in [
          ('light', RadarBaseMap.light, l10n.weatherRadarBaseLight),
          ('dark', RadarBaseMap.dark, l10n.weatherRadarBaseDark),
          ('satellite', RadarBaseMap.satellite, l10n.weatherRadarBaseSatellite),
        ])
          CheckedPopupMenuItem(
            value: value,
            checked: s.radarBaseMap == mode,
            child: Text(label),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: 'lightning',
          checked: s.radarLightning,
          child: Text(l10n.weatherRadarLightning),
        ),
        CheckedPopupMenuItem(
          value: 'warnings',
          checked: s.radarWarnings,
          child: Text(l10n.weatherRadarWarnings),
        ),
      ],
    );
  }
}
