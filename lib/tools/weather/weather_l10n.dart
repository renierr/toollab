import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'models/weather_condition.dart';
import 'models/weather_location.dart';
import 'weather_units.dart';

extension WeatherConditionL10n on WeatherCondition {
  String label(AppLocalizations l10n) => switch (this) {
    WeatherCondition.clear => l10n.weatherCondClear,
    WeatherCondition.mostlyClear => l10n.weatherCondMostlyClear,
    WeatherCondition.partlyCloudy => l10n.weatherCondPartlyCloudy,
    WeatherCondition.cloudy => l10n.weatherCondCloudy,
    WeatherCondition.overcast => l10n.weatherCondOvercast,
    WeatherCondition.fog => l10n.weatherCondFog,
    WeatherCondition.drizzle => l10n.weatherCondDrizzle,
    WeatherCondition.freezingDrizzle => l10n.weatherCondFreezingDrizzle,
    WeatherCondition.lightRain => l10n.weatherCondLightRain,
    WeatherCondition.rain => l10n.weatherCondRain,
    WeatherCondition.heavyRain => l10n.weatherCondHeavyRain,
    WeatherCondition.freezingRain => l10n.weatherCondFreezingRain,
    WeatherCondition.sleet => l10n.weatherCondSleet,
    WeatherCondition.lightSnow => l10n.weatherCondLightSnow,
    WeatherCondition.snow => l10n.weatherCondSnow,
    WeatherCondition.heavySnow => l10n.weatherCondHeavySnow,
    WeatherCondition.hail => l10n.weatherCondHail,
    WeatherCondition.rainShower => l10n.weatherCondRainShower,
    WeatherCondition.sleetShower => l10n.weatherCondSleetShower,
    WeatherCondition.snowShower => l10n.weatherCondSnowShower,
    WeatherCondition.thunderstorm => l10n.weatherCondThunderstorm,
  };
}

class WeatherL10n {
  WeatherL10n._();

  static String locationName(AppLocalizations l10n, WeatherLocation location) =>
      location.isDeviceLocation && location.name.isEmpty
      ? l10n.weatherMyLocation
      : location.name;

  static String direction(AppLocalizations l10n, double degrees) {
    final labels = [
      l10n.weatherDir0,
      l10n.weatherDir1,
      l10n.weatherDir2,
      l10n.weatherDir3,
      l10n.weatherDir4,
      l10n.weatherDir5,
      l10n.weatherDir6,
      l10n.weatherDir7,
      l10n.weatherDir8,
      l10n.weatherDir9,
      l10n.weatherDir10,
      l10n.weatherDir11,
      l10n.weatherDir12,
      l10n.weatherDir13,
      l10n.weatherDir14,
      l10n.weatherDir15,
    ];
    return labels[WeatherUnits.compassIndex(degrees)];
  }

  static String moonPhase(AppLocalizations l10n, int index) => switch (index) {
    0 => l10n.weatherMoonPhase0,
    1 => l10n.weatherMoonPhase1,
    2 => l10n.weatherMoonPhase2,
    3 => l10n.weatherMoonPhase3,
    4 => l10n.weatherMoonPhase4,
    5 => l10n.weatherMoonPhase5,
    6 => l10n.weatherMoonPhase6,
    _ => l10n.weatherMoonPhase7,
  };

  static String warningLevel(AppLocalizations l10n, int level) =>
      switch (level) {
        <= 1 => l10n.weatherWarningLevel1,
        2 => l10n.weatherWarningLevel2,
        3 => l10n.weatherWarningLevel3,
        _ => l10n.weatherWarningLevel4,
      };
}

/// Locale- and 24h-aware time formatting for the weather widgets.
class WeatherTimeFormat {
  WeatherTimeFormat(BuildContext context)
    : _locale = Localizations.localeOf(context).toLanguageTag(),
      _use24h = MediaQuery.alwaysUse24HourFormatOf(context);

  final String _locale;
  final bool _use24h;

  String time(DateTime t) =>
      (_use24h ? DateFormat.Hm(_locale) : DateFormat.jm(_locale)).format(
        t.toLocal(),
      );

  String hour(DateTime t) =>
      (_use24h ? DateFormat.H(_locale) : DateFormat.j(_locale)).format(
        t.toLocal(),
      );

  String weekdayShort(DateTime t) => DateFormat.E(_locale).format(t);

  String dayMonth(DateTime t) => DateFormat.MMMd(_locale).format(t);

  String weekdayDate(DateTime t) => DateFormat.MMMEd(_locale).format(t);

  String dayTime(DateTime t) =>
      DateFormat.E(_locale).add_Hm().format(t.toLocal());
}
