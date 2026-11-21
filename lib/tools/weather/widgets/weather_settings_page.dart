import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/widgets/background_task_tile.dart';
import 'package:tool_lab/widgets/confirm_action_dialog.dart';
import 'package:tool_lab/widgets/readable_width.dart';
import 'package:tool_lab/widgets/settings_section_label.dart';
import 'package:tool_lab_bridge/tool_lab_bridge.dart';

import '../weather_background.dart';
import '../weather_l10n.dart';
import '../weather_settings.dart';
import '../weather_state.dart';
import 'weather_choice_chips.dart';
import 'weather_radar_timeline.dart';

/// Pushed with a `MaterialPageRoute`, so a plain `Scaffold` instead of
/// `ToolLayout`, whose back button needs a GoRouter state.
class WeatherSettingsPage extends StatelessWidget {
  const WeatherSettingsPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const WeatherSettingsPage()));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<WeatherState>();
    final s = state.settings;
    void update(WeatherSettings next) => state.updateSettings(next);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weatherSettings)),
      body: ReadableScrollPadding(
        padding: const EdgeInsets.only(bottom: 32),
        builder: (context, padding) => ListView(
          padding: padding,
          children: [
            SettingsSectionLabel(
              title: l10n.weatherSettingsPlaces,
              description: l10n.weatherDefaultPlaceHint,
            ),
            _DefaultPlaceTile(state: state),
            SettingsSectionLabel(title: l10n.weatherUnits),
            ..._unitChoices(l10n, s, update),
            SettingsSectionLabel(title: l10n.weatherSettingsDisplay),
            SwitchListTile(
              title: Text(l10n.weatherAnimatedIcons),
              value: s.animatedIcons,
              onChanged: (v) => update(s.copyWith(animatedIcons: v)),
            ),
            WeatherChoiceChips<int>(
              label: l10n.weatherAutoRefresh,
              values: WeatherSettings.refreshChoices,
              selected: s.autoRefreshMinutes,
              text: (m) => m == 0
                  ? l10n.weatherRefreshOff
                  : l10n.weatherRefreshMinutes(m),
              onChanged: (m) => update(s.copyWith(autoRefreshMinutes: m)),
            ),
            if (BackgroundTaskService.isSupported) ...[
              SettingsSectionLabel(
                title: l10n.weatherSettingsBackground,
                description: l10n.weatherSettingsBackgroundHint,
              ),
              _BackgroundSettings(settings: s, onChanged: update),
            ],
            SettingsSectionLabel(
              title: l10n.weatherSettingsWarnings,
              description: l10n.weatherNotifyLevelHint,
            ),
            _WarningLevelChips(
              label: l10n.weatherNotifyLevel,
              level: s.warningNotifyLevel,
              onChanged: (level) =>
                  update(s.copyWith(warningNotifyLevel: level)),
            ),
            if (BackgroundTaskService.isSupported && s.warningNotifyLevel > 0)
              const _NotificationPermissionTile(),
            _WarningLevelChips(
              label: l10n.weatherShowLevel,
              level: s.warningShowLevel,
              onChanged: (level) => update(s.copyWith(warningShowLevel: level)),
            ),
            if (Platform.isAndroid) ...[
              SettingsSectionLabel(
                title: l10n.weatherSettingsWidget,
                description: l10n.weatherWidgetDetailsHint,
              ),
              WeatherFilterChips<WeatherWidgetDetail>(
                label: l10n.weatherWidgetDetails,
                values: WeatherWidgetDetail.values,
                selected: s.widgetDetails,
                text: (d) => switch (d) {
                  WeatherWidgetDetail.feelsLike => l10n.weatherFeelsLikeLabel,
                  WeatherWidgetDetail.wind => l10n.weatherWind,
                  WeatherWidgetDetail.rainChance =>
                    l10n.weatherPrecipitationProbability,
                  WeatherWidgetDetail.humidity => l10n.weatherHumidity,
                  WeatherWidgetDetail.sun => l10n.weatherSun,
                },
                onChanged: (d) => update(s.copyWith(widgetDetails: d)),
              ),
            ],
            SettingsSectionLabel(title: l10n.weatherSettingsRadar),
            _RadarSettings(settings: s, onChanged: update),
            SettingsSectionLabel(title: l10n.weatherSettingsData),
            WeatherChoiceChips<int>(
              label: l10n.weatherHistoryKeep,
              values: WeatherSettings.historyChoices,
              selected: s.historyMonths,
              text: (m) => m == 0
                  ? l10n.weatherHistoryKeepForever
                  : l10n.weatherHistoryKeepMonths(m),
              onChanged: (m) => update(s.copyWith(historyMonths: m)),
            ),
            const _HistoryStorageTile(),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l10n.weatherClearCache),
              subtitle: Text(l10n.weatherClearCacheHint),
              onTap: () => _clearCache(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _unitChoices(
    AppLocalizations l10n,
    WeatherSettings s,
    ValueChanged<WeatherSettings> update,
  ) => [
    WeatherChoiceChips<TemperatureUnit>(
      label: l10n.weatherTemperature,
      values: TemperatureUnit.values,
      selected: s.temperatureUnit,
      text: (u) => u == TemperatureUnit.celsius ? '°C' : '°F',
      onChanged: (u) => update(s.copyWith(temperatureUnit: u)),
    ),
    WeatherChoiceChips<WindUnit>(
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
    WeatherChoiceChips<PressureUnit>(
      label: l10n.weatherPressure,
      values: PressureUnit.values,
      selected: s.pressureUnit,
      text: (u) => u.name,
      onChanged: (u) => update(s.copyWith(pressureUnit: u)),
    ),
    WeatherChoiceChips<PrecipitationUnit>(
      label: l10n.weatherPrecipitation,
      values: PrecipitationUnit.values,
      selected: s.precipitationUnit,
      text: (u) => u == PrecipitationUnit.mm ? 'mm' : 'in',
      onChanged: (u) => update(s.copyWith(precipitationUnit: u)),
    ),
  ];

  Future<void> _clearCache(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<WeatherState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ConfirmActionDialog.show(
      context: context,
      title: l10n.weatherClearCache,
      message: l10n.weatherClearCacheHint,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (ok != true) return;
    await state.clearCache();
    messenger.showSnackBar(SnackBar(content: Text(l10n.weatherCacheCleared)));
  }
}

class _DefaultPlaceTile extends StatelessWidget {
  const _DefaultPlaceTile({required this.state});

  final WeatherState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = state.locationById(state.settings.defaultLocationId)?.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<int?>(
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l10n.weatherDefaultPlace,
          prefixIcon: const Icon(Icons.star_outline),
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(child: Text(l10n.weatherDefaultPlaceFirst)),
          for (final l in state.locations)
            DropdownMenuItem(
              value: l.id,
              child: Text(
                WeatherL10n.locationName(l10n, l),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: state.setDefault,
      ),
    );
  }
}

class _BackgroundSettings extends StatelessWidget {
  const _BackgroundSettings({required this.settings, required this.onChanged});

  final WeatherSettings settings;
  final ValueChanged<WeatherSettings> onChanged;

  static String _hour(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = settings;
    Widget hourPicker(int value, ValueChanged<int> pick) => DropdownButton<int>(
      value: value,
      underline: const SizedBox.shrink(),
      items: [
        for (var h = 0; h < 24; h++)
          DropdownMenuItem(value: h, child: Text(_hour(h))),
      ],
      onChanged: s.quietHours ? (h) => pick(h!) : null,
    );

    return Column(
      children: [
        BackgroundTaskTile(
          task: WeatherBackground.task,
          title: l10n.weatherBackgroundTask,
          description: l10n.weatherBackgroundTaskHint,
          icon: Icons.cloud_sync_outlined,
        ),
        WeatherChoiceChips<WeatherBackgroundScope>(
          label: l10n.weatherBackgroundScope,
          values: WeatherBackgroundScope.values,
          selected: s.backgroundScope,
          text: (v) => switch (v) {
            WeatherBackgroundScope.defaultPlace =>
              l10n.weatherBackgroundScopeDefault,
            WeatherBackgroundScope.allPlaces => l10n.weatherBackgroundScopeAll,
          },
          onChanged: (v) => onChanged(s.copyWith(backgroundScope: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.bedtime_outlined),
          title: Text(l10n.weatherQuietHours),
          subtitle: Text(l10n.weatherQuietHoursHint),
          value: s.quietHours,
          onChanged: (v) => onChanged(s.copyWith(quietHours: v)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 72, right: 16),
          child: Wrap(
            spacing: 24,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.weatherQuietFrom),
                  const SizedBox(width: 8),
                  hourPicker(
                    s.quietFrom,
                    (h) => onChanged(s.copyWith(quietFrom: h)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.weatherQuietTo),
                  const SizedBox(width: 8),
                  hourPicker(
                    s.quietTo,
                    (h) => onChanged(s.copyWith(quietTo: h)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.wifi),
          title: Text(l10n.weatherWifiOnly),
          subtitle: Text(l10n.weatherWifiOnlyHint),
          value: s.wifiOnly,
          onChanged: (v) => onChanged(s.copyWith(wifiOnly: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.battery_saver_outlined),
          title: Text(l10n.weatherBatteryNotLow),
          subtitle: Text(l10n.weatherBatteryNotLowHint),
          value: s.batteryNotLow,
          onChanged: (v) => onChanged(s.copyWith(batteryNotLow: v)),
        ),
      ],
    );
  }
}

class _RadarSettings extends StatelessWidget {
  const _RadarSettings({required this.settings, required this.onChanged});

  final WeatherSettings settings;
  final ValueChanged<WeatherSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = settings;
    return Column(
      children: [
        WeatherChoiceChips<RadarBaseMap>(
          label: l10n.weatherRadarBaseMap,
          values: RadarBaseMap.values,
          selected: s.radarBaseMap,
          text: (v) => switch (v) {
            RadarBaseMap.light => l10n.weatherRadarBaseLight,
            RadarBaseMap.dark => l10n.weatherRadarBaseDark,
            RadarBaseMap.satellite => l10n.weatherRadarBaseSatellite,
          },
          onChanged: (v) => onChanged(s.copyWith(radarBaseMap: v)),
        ),
        WeatherChoiceChips<double>(
          label: l10n.weatherRadarSpeed,
          values: WeatherRadarTimeline.speeds,
          selected: s.radarSpeed,
          text: (v) => '${v == v.roundToDouble() ? v.toInt() : v}×',
          onChanged: (v) => onChanged(s.copyWith(radarSpeed: v)),
        ),
        SwitchListTile(
          title: Text(l10n.weatherRadarLightning),
          value: s.radarLightning,
          onChanged: (v) => onChanged(s.copyWith(radarLightning: v)),
        ),
        SwitchListTile(
          title: Text(l10n.weatherRadarWarnings),
          value: s.radarWarnings,
          onChanged: (v) => onChanged(s.copyWith(radarWarnings: v)),
        ),
        SwitchListTile(
          title: Text(l10n.weatherRadarPanelSetting),
          subtitle: Text(l10n.weatherRadarPanelSettingHint),
          value: s.radarPanel,
          onChanged: (v) => onChanged(s.copyWith(radarPanel: v)),
        ),
      ],
    );
  }
}

/// Shown only while the system blocks the app's notifications.
class _NotificationPermissionTile extends StatefulWidget {
  const _NotificationPermissionTile();

  @override
  State<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState
    extends State<_NotificationPermissionTile>
    with DisposeCleanup {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _check();
    // Returning from the system settings page.
    final listener = AppLifecycleListener(onResume: _check);
    onDispose(listener.dispose);
  }

  Future<void> _check() async {
    final enabled = await ToolLabBridge.notificationsEnabled();
    if (mounted && enabled != _enabled) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        Icons.notifications_off_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(l10n.weatherNotificationsBlocked),
      trailing: TextButton(
        onPressed: ToolLabBridge.openNotificationSettings,
        child: Text(l10n.weatherNotificationsAllow),
      ),
    );
  }
}

/// How much history is stored, with a way to delete it.
class _HistoryStorageTile extends StatefulWidget {
  const _HistoryStorageTile();

  @override
  State<_HistoryStorageTile> createState() => _HistoryStorageTileState();
}

class _HistoryStorageTileState extends State<_HistoryStorageTile> {
  /// Rough size of one history row including its key, in bytes.
  static const int _bytesPerHour = 80;

  late Future<int> _count = context.read<WeatherState>().historyCount();

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final state = context.read<WeatherState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ConfirmActionDialog.show(
      context: context,
      title: l10n.weatherHistoryClear,
      message: l10n.weatherHistoryClearHint,
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.commonDelete,
    );
    if (ok != true) return;
    await state.clearHistory();
    if (!mounted) return;
    setState(() => _count = state.historyCount());
    messenger.showSnackBar(SnackBar(content: Text(l10n.weatherHistoryCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<int>(
      future: _count,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(l10n.weatherHistoryClear),
          subtitle: Text(
            l10n.weatherHistorySize(
              count,
              FormatHelper.fileSize(count * _bytesPerHour),
            ),
          ),
          onTap: count == 0 ? null : _clear,
        );
      },
    );
  }
}

/// Levels are thresholds, so the chosen one and every higher one light up.
class _WarningLevelChips extends StatelessWidget {
  const _WarningLevelChips({
    required this.label,
    required this.level,
    required this.onChanged,
  });

  final String label;
  final int level;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WeatherChoiceChips<int>(
      label: label,
      values: const [0, 1, 2, 3, 4],
      selected: level,
      isSelected: (v) => level == 0 ? v == 0 : v >= level,
      text: (v) =>
          v == 0 ? l10n.weatherRefreshOff : WeatherL10n.warningLevel(l10n, v),
      onChanged: onChanged,
    );
  }
}
