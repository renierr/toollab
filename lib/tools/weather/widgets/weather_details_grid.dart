import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/astronomy.dart';
import '../models/daily_forecast.dart';
import '../models/weather_snapshot.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';
import 'weather_detail_tile.dart';
import 'weather_moon_view.dart';
import 'weather_sun_arc.dart';
import 'weather_wind_compass.dart';

class WeatherDetailsGrid extends StatelessWidget {
  const WeatherDetailsGrid({
    super.key,
    required this.snapshot,
    required this.current,
    required this.today,
    required this.units,
    required this.now,
  });

  final WeatherSnapshot snapshot;
  final CurrentConditions current;
  final DailyForecast? today;
  final WeatherUnits units;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = WeatherTimeFormat(context);
    final sun = snapshot.sunTimes(now);
    final moon = MoonState.at(now);
    final pressureTrend = _pressureTrend();
    final rain24 = snapshot.liveObservation(now)?.precipitation24h;
    final windDir = current.windDirection;

    final tiles = <Widget>[
      WeatherDetailTile(
        icon: Icons.air,
        label: l10n.weatherWind,
        value: units.windText(current.windSpeed),
        caption: [
          if (windDir != null) WeatherL10n.direction(l10n, windDir),
          if (current.windGust != null)
            l10n.weatherGusts(units.windText(current.windGust)),
        ].join(' · '),
        accent: WeatherColors.windLine,
        visual: WeatherWindCompass(direction: windDir, size: 52),
      ),
      if (sun.sunrise != null && sun.sunset != null)
        WeatherDetailTile(
          icon: Icons.wb_twilight,
          label: l10n.weatherSun,
          value: format.time(
            sun.sunset!.isAfter(now) && sun.sunrise!.isBefore(now)
                ? sun.sunset!
                : sun.sunrise!,
          ),
          caption:
              '${l10n.weatherSunrise} ${format.time(sun.sunrise!)} · ${l10n.weatherSunset} ${format.time(sun.sunset!)}\n${l10n.weatherDaylight(_duration(sun.sunset!.difference(sun.sunrise!)))}',
          accent: WeatherColors.sun,
          visual: WeatherSunArc(
            sunrise: sun.sunrise!,
            sunset: sun.sunset!,
            now: now,
            width: 72,
          ),
        ),
      WeatherDetailTile(
        icon: Icons.water_drop_outlined,
        label: l10n.weatherHumidity,
        value: WeatherUnits.percentText(current.humidity),
        caption:
            '${l10n.weatherDewPoint} ${units.temperatureText(current.dewPoint)}',
        accent: WeatherColors.rain,
      ),
      WeatherDetailTile(
        icon: Icons.umbrella_outlined,
        label: l10n.weatherPrecipitation,
        value: units.precipitationText(
          today?.precipitationSum ?? current.precipitation,
        ),
        caption: [
          if (today?.precipitationProbability != null)
            '${l10n.weatherPrecipitationProbability} ${WeatherUnits.percentText(today!.precipitationProbability)}',
          if (rain24 != null)
            l10n.weatherPrecipitation24h(units.precipitationText(rain24)),
        ].join('\n'),
        accent: WeatherColors.precipitationBar,
      ),
      WeatherDetailTile(
        icon: Icons.speed,
        label: l10n.weatherPressure,
        value: units.pressureText(current.pressure),
        caption: pressureTrend == null
            ? null
            : '${pressureTrend >= 0 ? '+' : ''}${pressureTrend.toStringAsFixed(1)} hPa / 3 h',
        accent: WeatherColors.pressureLine,
      ),
      WeatherDetailTile(
        icon: Icons.cloud_outlined,
        label: l10n.weatherCloudCover,
        value: WeatherUnits.percentText(current.cloudCover),
        caption:
            '${l10n.weatherVisibility} ${WeatherUnits.visibilityText(current.visibility)}',
      ),
      if (today?.sunshineHours != null)
        WeatherDetailTile(
          icon: Icons.wb_sunny_outlined,
          label: l10n.weatherSunshine,
          value: l10n.weatherSunshineHours(
            today!.sunshineHours!.toStringAsFixed(1),
          ),
          accent: WeatherColors.sun,
        ),
      WeatherDetailTile(
        icon: Icons.nightlight_outlined,
        label: l10n.weatherMoon,
        value: WeatherUnits.percentText(moon.illumination * 100),
        caption: WeatherL10n.moonPhase(l10n, moon.phaseIndex),
        visual: WeatherMoonView(moon: moon, size: 44),
        accent: WeatherColors.moon,
      ),
    ];

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 150,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: tiles,
    );
  }

  double? _pressureTrend() {
    final hours = snapshot.forecast?.hours;
    final pressure = current.pressure;
    if (hours == null || pressure == null) return null;
    final target = now.add(const Duration(hours: 3));
    for (final h in hours) {
      if (!h.time.isBefore(target) && h.pressure != null) {
        return h.pressure! - pressure;
      }
    }
    return null;
  }

  static String _duration(Duration d) =>
      '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')} h';
}
