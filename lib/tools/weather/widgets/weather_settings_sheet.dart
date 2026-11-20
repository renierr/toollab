import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';

import '../weather_l10n.dart';
import '../weather_settings.dart';
import '../weather_state.dart';

class WeatherSettingsSheet extends StatelessWidget {
  const WeatherSettingsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const WeatherSettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<WeatherState>();
    final s = state.settings;
    void update(WeatherSettings next) => state.updateSettings(next);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SettingsSectionLabel(title: l10n.weatherUnits),
          _Choice<TemperatureUnit>(
            label: l10n.weatherTemperature,
            values: TemperatureUnit.values,
            selected: s.temperatureUnit,
            text: (u) => u == TemperatureUnit.celsius ? '°C' : '°F',
            onChanged: (u) => update(s.copyWith(temperatureUnit: u)),
          ),
          _Choice<WindUnit>(
            label: l10n.weatherWind,
            values: WindUnit.values,
            selected: s.windUnit,
            text: (u) => switch (u) {
              WindUnit.kmh => 'km/h',
              WindUnit.ms => 'm/s',
              WindUnit.knots => 'kn',
              WindUnit.beaufort => 'Bft',
              WindUnit.mph => 'mph',
            },
            onChanged: (u) => update(s.copyWith(windUnit: u)),
          ),
          _Choice<PressureUnit>(
            label: l10n.weatherPressure,
            values: PressureUnit.values,
            selected: s.pressureUnit,
            text: (u) => u.name,
            onChanged: (u) => update(s.copyWith(pressureUnit: u)),
          ),
          _Choice<PrecipitationUnit>(
            label: l10n.weatherPrecipitation,
            values: PrecipitationUnit.values,
            selected: s.precipitationUnit,
            text: (u) => u == PrecipitationUnit.mm ? 'mm' : 'in',
            onChanged: (u) => update(s.copyWith(precipitationUnit: u)),
          ),
          const SizedBox(height: 8),
          SettingsSectionLabel(title: l10n.weatherAutoRefresh),
          _Choice<int>(
            values: WeatherSettings.refreshChoices,
            selected: s.autoRefreshMinutes,
            text: (m) =>
                m == 0 ? l10n.weatherRefreshOff : l10n.weatherRefreshMinutes(m),
            onChanged: (m) => update(s.copyWith(autoRefreshMinutes: m)),
          ),
          const SizedBox(height: 8),
          SettingsSectionLabel(
            title: l10n.weatherNotifyLevel,
            description: l10n.weatherNotifyLevelHint,
          ),
          _Choice<int>(
            values: const [0, 1, 2, 3, 4],
            selected: s.warningNotifyLevel,
            text: (level) => level == 0
                ? l10n.weatherRefreshOff
                : WeatherL10n.warningLevel(l10n, level),
            onChanged: (level) => update(s.copyWith(warningNotifyLevel: level)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.weatherAnimatedIcons),
            value: s.animatedIcons,
            onChanged: (v) => update(s.copyWith(animatedIcons: v)),
          ),
        ],
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    this.label,
    required this.values,
    required this.selected,
    required this.text,
    required this.onChanged,
  });

  final String? label;
  final List<T> values;
  final T selected;
  final String Function(T value) text;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(text(v)),
                  selected: v == selected,
                  onSelected: (_) => onChanged(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
