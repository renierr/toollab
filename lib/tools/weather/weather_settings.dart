import 'package:tool_lab/services/database_service.dart';

import 'config.dart';

enum TemperatureUnit { celsius, fahrenheit }

enum WindUnit { kmh, ms, knots, beaufort, mph }

enum PressureUnit { hPa, mmHg, inHg }

enum PrecipitationUnit { mm, inch }

enum RadarBaseMap { light, dark, satellite }

class WeatherSettings {
  const WeatherSettings({
    this.temperatureUnit = TemperatureUnit.celsius,
    this.windUnit = WindUnit.kmh,
    this.pressureUnit = PressureUnit.hPa,
    this.precipitationUnit = PrecipitationUnit.mm,
    this.defaultLocationId,
    this.autoRefreshMinutes = 30,
    this.warningNotifyLevel = 2,
    this.animatedIcons = true,
    this.radarBaseMap = RadarBaseMap.light,
    this.radarSpeed = 1.0,
    this.radarLightning = false,
    this.radarWarnings = false,
    this.radarPanel = false,
  });

  static const List<int> refreshChoices = [0, 15, 30, 60, 120];

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
  final bool animatedIcons;
  final RadarBaseMap radarBaseMap;
  final double radarSpeed;
  final bool radarLightning;
  final bool radarWarnings;

  /// Desktop only: radar as a side panel instead of a preview card.
  final bool radarPanel;

  static const _kTemp = 'unit_temperature';
  static const _kWind = 'unit_wind';
  static const _kPressure = 'unit_pressure';
  static const _kPrecip = 'unit_precipitation';
  static const _kDefault = 'default_location';
  static const _kRefresh = 'auto_refresh_minutes';
  static const _kNotify = 'warning_notify_level';
  static const _kAnimated = 'animated_icons';
  static const _kBaseMap = 'radar_base_map';
  static const _kSpeed = 'radar_speed';
  static const _kLightning = 'radar_lightning';
  static const _kWarnings = 'radar_warnings';
  static const _kPanel = 'radar_panel';

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
      animatedIcons: s[_kAnimated] != 'false',
      radarBaseMap: pick(RadarBaseMap.values, _kBaseMap, RadarBaseMap.light),
      radarSpeed: double.tryParse(s[_kSpeed] ?? '') ?? 1.0,
      radarLightning: s[_kLightning] == 'true',
      radarWarnings: s[_kWarnings] == 'true',
      radarPanel: s[_kPanel] == 'true',
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
      db.setSetting(id, _kAnimated, '$animatedIcons'),
      db.setSetting(id, _kBaseMap, radarBaseMap.name),
      db.setSetting(id, _kSpeed, '$radarSpeed'),
      db.setSetting(id, _kLightning, '$radarLightning'),
      db.setSetting(id, _kWarnings, '$radarWarnings'),
      db.setSetting(id, _kPanel, '$radarPanel'),
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
    bool? animatedIcons,
    RadarBaseMap? radarBaseMap,
    double? radarSpeed,
    bool? radarLightning,
    bool? radarWarnings,
    bool? radarPanel,
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
    animatedIcons: animatedIcons ?? this.animatedIcons,
    radarBaseMap: radarBaseMap ?? this.radarBaseMap,
    radarSpeed: radarSpeed ?? this.radarSpeed,
    radarLightning: radarLightning ?? this.radarLightning,
    radarWarnings: radarWarnings ?? this.radarWarnings,
    radarPanel: radarPanel ?? this.radarPanel,
  );
}
