import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../models/weather_history_summary.dart';
import '../weather_colors.dart';
import '../weather_l10n.dart';
import '../weather_units.dart';
import 'weather_detail_tile.dart';

/// Key figures of a history period as detail tiles.
class WeatherHistoryStats extends StatelessWidget {
  const WeatherHistoryStats({
    super.key,
    required this.summary,
    required this.units,
  });

  final HistorySummary summary;
  final WeatherUnits units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = WeatherTimeFormat(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final singleDay = summary.range.period == HistoryPeriod.day;
    String when(DateTime t) => singleDay ? format.time(t) : format.dayTime(t);
    String day(DateTime t) => DateFormat.MMMEd(locale).format(t);
    final total = summary.total;
    final cold = summary.coldestHour;
    final warm = summary.warmestHour;
    final gustHour = summary.entries
        .where((e) => e.windGust != null && e.windGust == total.maxGust)
        .firstOrNull;
    final warmestDay = summary.warmestDay;
    final coldestDay = summary.coldestDay;
    final wettestDay = summary.wettestDay;

    final tiles = <Widget>[
      if (cold != null)
        WeatherDetailTile(
          icon: Icons.south,
          label: l10n.weatherHistoryLowest,
          value: units.temperatureText(cold.temperature),
          caption: when(cold.hour),
          accent: WeatherColors.temperature(cold.temperature!),
        ),
      if (warm != null)
        WeatherDetailTile(
          icon: Icons.north,
          label: l10n.weatherHistoryHighest,
          value: units.temperatureText(warm.temperature),
          caption: when(warm.hour),
          accent: WeatherColors.temperature(warm.temperature!),
        ),
      if (total.meanTemperature != null)
        WeatherDetailTile(
          icon: Icons.thermostat,
          label: l10n.weatherHistoryAverage,
          value: units.temperatureText(total.meanTemperature),
          accent: WeatherColors.temperatureLine,
        ),
      WeatherDetailTile(
        icon: Icons.umbrella_outlined,
        label: l10n.weatherPrecipitation,
        value: units.precipitationText(total.precipitation),
        caption: singleDay
            ? null
            : '${l10n.weatherHistoryRainDays}: ${summary.rainDays}',
        accent: WeatherColors.precipitationBar,
      ),
      if (total.sunshineMinutes > 0)
        WeatherDetailTile(
          icon: Icons.wb_sunny_outlined,
          label: l10n.weatherSunshine,
          value: l10n.weatherSunshineHours(
            (total.sunshineMinutes / 60).toStringAsFixed(1),
          ),
          accent: WeatherColors.sun,
        ),
      if (total.maxGust != null)
        WeatherDetailTile(
          icon: Icons.air,
          label: l10n.weatherHistoryMaxGust,
          value: units.windText(total.maxGust),
          caption: gustHour == null ? null : when(gustHour.hour),
          accent: WeatherColors.windLine,
        ),
      if (!singleDay && warmestDay != null)
        WeatherDetailTile(
          icon: Icons.local_fire_department_outlined,
          label: l10n.weatherHistoryWarmestDay,
          value: units.temperatureText(warmestDay.maxTemperature),
          caption: day(warmestDay.start),
          accent: WeatherColors.temperature(warmestDay.maxTemperature!),
        ),
      if (!singleDay && coldestDay != null)
        WeatherDetailTile(
          icon: Icons.ac_unit,
          label: l10n.weatherHistoryColdestDay,
          value: units.temperatureText(coldestDay.minTemperature),
          caption: day(coldestDay.start),
          accent: WeatherColors.temperature(coldestDay.minTemperature!),
        ),
      if (!singleDay && wettestDay != null)
        WeatherDetailTile(
          icon: Icons.water_drop_outlined,
          label: l10n.weatherHistoryWettestDay,
          value: units.precipitationText(wettestDay.precipitation),
          caption: day(wettestDay.start),
          accent: WeatherColors.precipitationBar,
        ),
    ];

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 112,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: tiles,
    );
  }
}
