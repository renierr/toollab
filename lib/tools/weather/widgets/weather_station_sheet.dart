import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../api/station_catalog.dart';
import '../models/weather_location.dart';
import '../weather_state.dart';

class WeatherStationSheet extends StatefulWidget {
  const WeatherStationSheet({super.key, required this.location});

  final WeatherLocation location;

  static Future<void> show(BuildContext context, WeatherLocation location) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (_) => WeatherStationSheet(location: location),
      );

  @override
  State<WeatherStationSheet> createState() => _WeatherStationSheetState();
}

class _WeatherStationSheetState extends State<WeatherStationSheet> {
  late String? _forecast = widget.location.forecastStationId;
  late String? _observation = widget.location.observationStationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.read<WeatherState>();
    final forecastChoices = state.stationChoices(
      widget.location,
      observations: false,
    );
    final observationChoices = state.stationChoices(
      widget.location,
      observations: true,
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      maxChildSize: .95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                _StationGroup(
                  title: l10n.weatherStationForecast,
                  icon: Icons.auto_graph,
                  choices: forecastChoices,
                  selected: _forecast,
                  onChanged: (id) => setState(() => _forecast = id),
                ),
                const Divider(),
                _StationGroup(
                  title: l10n.weatherStationObservation,
                  icon: Icons.sensors,
                  choices: observationChoices,
                  selected: _observation,
                  onChanged: (id) => setState(() => _observation = id),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: Text(l10n.commonSave),
                onPressed: () {
                  Navigator.pop(context);
                  state.pinStations(
                    widget.location.id!,
                    forecast: _forecast,
                    observation: _observation,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationGroup extends StatelessWidget {
  const _StationGroup({
    required this.title,
    required this.icon,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final List<StationMatch> choices;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return RadioGroup<String?>(
      groupValue: selected,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          RadioListTile<String?>(
            value: null,
            title: Text(l10n.weatherStationAuto),
          ),
          for (final m in choices)
            RadioListTile<String?>(
              value: m.station.id,
              title: Text(m.station.name),
              subtitle: Text(
                l10n.weatherStationDistance(
                  m.distanceKm.toStringAsFixed(1),
                  '${m.station.elevation}',
                ),
              ),
              secondary: Text(m.station.id, style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}
