import 'dart:math' as math;

import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

enum TemperatureUnit { celsius, fahrenheit }

enum WindUnit { kmh, ms, knots, beaufort, mph }

enum PressureUnit { hPa, mmHg, inHg }

enum PrecipitationUnit { mm, inch }

enum RadarBaseMap { light, dark, satellite }

/// Extra lines a wide home screen widget shows beside the temperature.
enum WeatherWidgetDetail { feelsLike, wind, rainChance, humidity, sun }

/// Which places a background run refreshes.
enum WeatherBackgroundScope { defaultPlace, allPlaces }

class WeatherSettings {
  const WeatherSettings({
    this.temperatureUnit = TemperatureUnit.celsius,
    this.windUnit = WindUnit.kmh,
    this.pressureUnit = PressureUnit.hPa,
    this.precipitationUnit = PrecipitationUnit.mm,
    this.defaultLocationId,
    this.autoRefreshMinutes = 30,
    this.warningNotifyLevel = 2,
    this.warningShowLevel = 1,
    this.widgetDetails = const {...WeatherWidgetDetail.values},
    this.animatedIcons = true,
    this.radarBaseMap = RadarBaseMap.light,
    this.radarSpeed = 1.0,
    this.radarLightning = false,
    this.radarWarnings = false,
    this.radarPanel = false,
    this.backgroundScope = WeatherBackgroundScope.defaultPlace,
    this.quietHours = true,
    this.quietFrom = 23,
    this.quietTo = 6,
    this.wifiOnly = false,
    this.batteryNotLow = true,
    this.historyMonths = 12,
  });

  static const List<int> refreshChoices = [0, 15, 30, 60, 120];

  /// 0 keeps the history forever.
  static const List<int> historyChoices = [3, 6, 12, 24, 0];

  final TemperatureUnit temperatureUnit;
  final WindUnit windUnit;
  final PressureUnit pressureUnit;
  final PrecipitationUnit precipitationUnit;

  /// Location shown on open and used by the widget; null = first in list.
  final int? defaultLocationId;

  /// 0 disables refreshing while the tool is open.
  final int autoRefreshMinutes;

  /// Lowest DWD level that raises a notification; 0 = off.
  final int warningNotifyLevel;

  /// Lowest DWD level shown in the overview and the widget; 0 = off.
  final int warningShowLevel;
  final Set<WeatherWidgetDetail> widgetDetails;

  /// DWD level 0 items (e.g. heat notices) count as the lowest level.
  bool showsWarning(int level) =>
      warningShowLevel > 0 && math.max(level, 1) >= warningShowLevel;
  final bool animatedIcons;
  final RadarBaseMap radarBaseMap;
  final double radarSpeed;
  final bool radarLightning;
  final bool radarWarnings;

  /// Desktop only: radar as a side panel instead of a preview card.
  final bool radarPanel;

  final WeatherBackgroundScope backgroundScope;

  /// Background runs are skipped from [quietFrom] to [quietTo] (local hours).
  final bool quietHours;
  final int quietFrom;
  final int quietTo;
  final bool wifiOnly;
  final bool batteryNotLow;

  /// Months of history kept; 0 = forever.
  final int historyMonths;

  /// Hours before this are dropped; null keeps everything.
  DateTime? historyCutoff(DateTime now) => historyMonths <= 0
      ? null
      : DateTime(now.year, now.month - historyMonths, now.day);

  bool isQuietAt(DateTime local) {
    if (!quietHours || quietFrom == quietTo) return false;
    final h = local.hour;
    return quietFrom < quietTo
        ? h >= quietFrom && h < quietTo
        : h >= quietFrom || h < quietTo;
  }

  static const _kTemp = 'unit_temperature';
  static const _kWind = 'unit_wind';
  static const _kPressure = 'unit_pressure';
  static const _kPrecip = 'unit_precipitation';
  static const _kDefault = 'default_location';
  static const _kRefresh = 'auto_refresh_minutes';
  static const _kNotify = 'warning_notify_level';
  static const _kShow = 'warning_show_level';
  static const _kWidgetDetails = 'widget_details';
  static const _kAnimated = 'animated_icons';
  static const _kBaseMap = 'radar_base_map';
  static const _kSpeed = 'radar_speed';
  static const _kLightning = 'radar_lightning';
  static const _kWarnings = 'radar_warnings';
  static const _kPanel = 'radar_panel';
  static const _kBgScope = 'background_scope';
  static const _kQuiet = 'quiet_hours';
  static const _kQuietFrom = 'quiet_from';
  static const _kQuietTo = 'quiet_to';
  static const _kWifi = 'background_wifi_only';
  static const _kBattery = 'background_battery_not_low';
  static const _kHistory = 'history_months';

  static Future<WeatherSettings> load() async {
    final s = await DatabaseService.instance.getAllSettings(
      WeatherTool.config.id,
    );
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.asNameMap()[s[key]] ?? fallback;
    return WeatherSettings(
      temperatureUnit: pick(
        TemperatureUnit.values,
        _kTemp,
        TemperatureUnit.celsius,
      ),
      windUnit: pick(WindUnit.values, _kWind, WindUnit.kmh),
      pressureUnit: pick(PressureUnit.values, _kPressure, PressureUnit.hPa),
      precipitationUnit: pick(
        PrecipitationUnit.values,
        _kPrecip,
        PrecipitationUnit.mm,
      ),
      defaultLocationId: int.tryParse(s[_kDefault] ?? ''),
      autoRefreshMinutes: int.tryParse(s[_kRefresh] ?? '') ?? 30,
      warningNotifyLevel: int.tryParse(s[_kNotify] ?? '') ?? 2,
      warningShowLevel: int.tryParse(s[_kShow] ?? '') ?? 1,
      widgetDetails: switch (s[_kWidgetDetails]) {
        null => {...WeatherWidgetDetail.values},
        final names => {
          for (final n in names.split(','))
            ?WeatherWidgetDetail.values.asNameMap()[n],
        },
      },
      animatedIcons: s[_kAnimated] != 'false',
      radarBaseMap: pick(RadarBaseMap.values, _kBaseMap, RadarBaseMap.light),
      radarSpeed: double.tryParse(s[_kSpeed] ?? '') ?? 1.0,
      radarLightning: s[_kLightning] == 'true',
      radarWarnings: s[_kWarnings] == 'true',
      radarPanel: s[_kPanel] == 'true',
      backgroundScope: pick(
        WeatherBackgroundScope.values,
        _kBgScope,
        WeatherBackgroundScope.defaultPlace,
      ),
      quietHours: s[_kQuiet] != 'false',
      quietFrom: int.tryParse(s[_kQuietFrom] ?? '') ?? 23,
      quietTo: int.tryParse(s[_kQuietTo] ?? '') ?? 6,
      wifiOnly: s[_kWifi] == 'true',
      batteryNotLow: s[_kBattery] != 'false',
      historyMonths: int.tryParse(s[_kHistory] ?? '') ?? 12,
    );
  }

  Future<void> save() async {
    final db = DatabaseService.instance;
    final id = WeatherTool.config.id;
    await Future.wait([
      db.setSetting(id, _kTemp, temperatureUnit.name),
      db.setSetting(id, _kWind, windUnit.name),
      db.setSetting(id, _kPressure, pressureUnit.name),
      db.setSetting(id, _kPrecip, precipitationUnit.name),
      if (defaultLocationId == null)
        db.deleteSetting(id, _kDefault)
      else
        db.setSetting(id, _kDefault, '$defaultLocationId'),
      db.setSetting(id, _kRefresh, '$autoRefreshMinutes'),
      db.setSetting(id, _kNotify, '$warningNotifyLevel'),
      db.setSetting(id, _kShow, '$warningShowLevel'),
      db.setSetting(
        id,
        _kWidgetDetails,
        WeatherWidgetDetail.values
            .where(widgetDetails.contains)
            .map((d) => d.name)
            .join(','),
      ),
      db.setSetting(id, _kAnimated, '$animatedIcons'),
      db.setSetting(id, _kBaseMap, radarBaseMap.name),
      db.setSetting(id, _kSpeed, '$radarSpeed'),
      db.setSetting(id, _kLightning, '$radarLightning'),
      db.setSetting(id, _kWarnings, '$radarWarnings'),
      db.setSetting(id, _kPanel, '$radarPanel'),
      db.setSetting(id, _kBgScope, backgroundScope.name),
      db.setSetting(id, _kQuiet, '$quietHours'),
      db.setSetting(id, _kQuietFrom, '$quietFrom'),
      db.setSetting(id, _kQuietTo, '$quietTo'),
      db.setSetting(id, _kWifi, '$wifiOnly'),
      db.setSetting(id, _kBattery, '$batteryNotLow'),
      db.setSetting(id, _kHistory, '$historyMonths'),
    ]);
  }

  WeatherSettings copyWith({
    TemperatureUnit? temperatureUnit,
    WindUnit? windUnit,
    PressureUnit? pressureUnit,
    PrecipitationUnit? precipitationUnit,
    int? Function()? defaultLocationId,
    int? autoRefreshMinutes,
    int? warningNotifyLevel,
    int? warningShowLevel,
    Set<WeatherWidgetDetail>? widgetDetails,
    bool? animatedIcons,
    RadarBaseMap? radarBaseMap,
    double? radarSpeed,
    bool? radarLightning,
    bool? radarWarnings,
    bool? radarPanel,
    WeatherBackgroundScope? backgroundScope,
    bool? quietHours,
    int? quietFrom,
    int? quietTo,
    bool? wifiOnly,
    bool? batteryNotLow,
    int? historyMonths,
  }) => WeatherSettings(
    temperatureUnit: temperatureUnit ?? this.temperatureUnit,
    windUnit: windUnit ?? this.windUnit,
    pressureUnit: pressureUnit ?? this.pressureUnit,
    precipitationUnit: precipitationUnit ?? this.precipitationUnit,
    defaultLocationId: defaultLocationId == null
        ? this.defaultLocationId
        : defaultLocationId(),
    autoRefreshMinutes: autoRefreshMinutes ?? this.autoRefreshMinutes,
    warningNotifyLevel: warningNotifyLevel ?? this.warningNotifyLevel,
    warningShowLevel: warningShowLevel ?? this.warningShowLevel,
    widgetDetails: widgetDetails ?? this.widgetDetails,
    animatedIcons: animatedIcons ?? this.animatedIcons,
    radarBaseMap: radarBaseMap ?? this.radarBaseMap,
    radarSpeed: radarSpeed ?? this.radarSpeed,
    radarLightning: radarLightning ?? this.radarLightning,
    radarWarnings: radarWarnings ?? this.radarWarnings,
    radarPanel: radarPanel ?? this.radarPanel,
    backgroundScope: backgroundScope ?? this.backgroundScope,
    quietHours: quietHours ?? this.quietHours,
    quietFrom: quietFrom ?? this.quietFrom,
    quietTo: quietTo ?? this.quietTo,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    batteryNotLow: batteryNotLow ?? this.batteryNotLow,
    historyMonths: historyMonths ?? this.historyMonths,
  );
}
