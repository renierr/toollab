import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/headless_localizations.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab_bridge/tool_lab_bridge.dart';

import 'api/station_catalog.dart';
import 'models/daily_forecast.dart';
import 'models/hourly_forecast.dart';
import 'models/weather_condition.dart';
import 'models/weather_location.dart';
import 'models/weather_snapshot.dart';
import 'models/weather_warning.dart';
import 'weather_colors.dart';
import 'weather_db_helper.dart';
import 'weather_l10n.dart';
import 'weather_repository.dart';
import 'weather_settings.dart';
import 'weather_units.dart';
import 'weather_warning_alerts.dart';

/// Hands the weather to the native Android side: the home screen widget
/// snapshot (`files/weather/widget.json`) and warning notifications. Works in
/// a headless background run, since the bridge plugin exists in every engine.
class WeatherPublisher {
  WeatherPublisher._();

  static const String actionRefresh =
      'de.renier.tool_lab.weather.REFRESH_WIDGETS';
  static const String actionNotify = 'de.renier.tool_lab.weather.NOTIFY';
  static const int _hours = 5;
  static const int _days = 5;
  static const int _bodyLength = 400;

  /// Places missing from [known] are read from the cache, so it costs no
  /// network requests; [known] spares parsing the forecasts again.
  static Future<void> publish({
    WeatherRepository? repository,
    StationCatalog? catalog,
    Map<int, WeatherSnapshot> known = const {},
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final now = DateTime.now();
      final settings = await WeatherSettings.load();
      final locations = await WeatherDbHelper.instance.getLocations();
      final missing = [
        for (final l in locations)
          if (!(known[l.id]?.hasData ?? false)) l,
      ];
      final repo = repository ?? WeatherRepository();
      final stations = missing.isEmpty
          ? null
          : catalog ?? await StationCatalog.load();
      final snapshots = <int, WeatherSnapshot>{
        for (final l in locations)
          if (known[l.id] case final s? when s.hasData) l.id!: s,
        for (final l in missing)
          l.id!: await repo.load(l, stations!, cacheOnly: true),
      };
      final l10n = await headlessLocalizations();
      await _writeWidget(
        widgetJson(
          locations: locations,
          snapshots: snapshots,
          settings: settings,
          l10n: l10n,
          now: now,
        ),
      );
      await ToolLabBridge.broadcast(actionRefresh);

      final home = defaultPlace(locations, settings);
      final warnings = home == null
          ? const <WeatherWarning>[]
          : snapshots[home.id]?.warnings(now) ?? const <WeatherWarning>[];
      final fresh = await WeatherWarningAlerts().takeNew(
        warnings,
        settings.warningNotifyLevel,
        now,
      );
      for (final w in fresh) {
        await ToolLabBridge.broadcast(
          actionNotify,
          notification(
            w,
            place: WeatherL10n.locationName(l10n, home!),
            placeId: home.id!,
            l10n: l10n,
          ),
        );
      }
    } catch (e) {
      errorLog('[WeatherPublisher] publish failed: $e');
    }
  }

  static WeatherLocation? defaultPlace(
    List<WeatherLocation> locations,
    WeatherSettings settings,
  ) =>
      locations.where((l) => l.id == settings.defaultLocationId).firstOrNull ??
      locations.firstOrNull;

  static Map<String, Object> notification(
    WeatherWarning w, {
    required String place,
    required int placeId,
    required AppLocalizations l10n,
  }) {
    final time = DateFormat.E(l10n.localeName).add_Hm();
    final timing = [
      if (w.start.isAfter(DateTime.now()))
        l10n.weatherWarningFrom(time.format(w.start.toLocal())),
      if (w.end != null)
        l10n.weatherWarningUntil(time.format(w.end!.toLocal())),
    ].join(' ');
    final body = [
      if (timing.isNotEmpty) timing,
      if (w.description.isNotEmpty) w.description,
    ].join('\n');
    final headline = w.headline.isEmpty
        ? WeatherL10n.warningLevel(l10n, w.level)
        : w.headline;
    return {
      'key': w.id.isEmpty ? '${w.event}|${w.level}|${w.start}' : w.id,
      'title': '$headline · $place',
      'body': body.length > _bodyLength
          ? '${body.substring(0, _bodyLength)}…'
          : body,
      // Android reads an int extra; ARGB above 0x7FFFFFFF must wrap.
      'color': WeatherColors.warning(w.level).toARGB32().toSigned(32),
      'placeId': placeId,
    };
  }

  static Map<String, Object?> widgetJson({
    required List<WeatherLocation> locations,
    required Map<int, WeatherSnapshot> snapshots,
    required WeatherSettings settings,
    required AppLocalizations l10n,
    required DateTime now,
  }) {
    final units = WeatherUnits(settings);
    final locale = l10n.localeName;
    final home = defaultPlace(locations, settings);
    return {
      'updatedAt': now.millisecondsSinceEpoch,
      'defaultId': ?home?.id,
      'places': [
        for (final l in locations)
          if (snapshots[l.id] case final s? when s.hasData)
            _place(l, s, units, settings, l10n, locale, now),
      ],
    };
  }

  static Map<String, Object?> _place(
    WeatherLocation location,
    WeatherSnapshot snapshot,
    WeatherUnits units,
    WeatherSettings settings,
    AppLocalizations l10n,
    String locale,
    DateTime now,
  ) {
    final current = snapshot.current(now)!;
    final isDay = snapshot.isDayAt(now);
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (final d in snapshot.forecast?.days ?? const <DailyForecast>[])
        if (!d.date.isBefore(today)) d,
    ];
    final todayForecast = days.firstOrNull;
    final hours = [
      for (final h in snapshot.forecast?.hours ?? const <HourlyForecast>[])
        if (h.time.isAfter(now)) h,
    ].take(_hours);
    final warning = snapshot
        .warnings(now)
        .where((w) => settings.showsWarning(w.level))
        .firstOrNull;
    return {
      'id': location.id,
      'name': WeatherL10n.locationName(l10n, location),
      'temp': units.temperatureText(current.temperature),
      'condition': current.condition.label(l10n),
      'icon': iconKey(current.condition, isDay),
      'theme': theme(current.condition, isDay),
      'range': todayForecast == null
          ? ''
          : '${units.temperatureText(todayForecast.maxTemperature)} / '
                '${units.temperatureText(todayForecast.minTemperature)}',
      'updated': l10n.weatherUpdated(
        DateFormat.Hm(locale).format(snapshot.fetchedAt.toLocal()),
      ),
      'details': _details(
        current,
        todayForecast,
        snapshot,
        units,
        settings.widgetDetails,
        l10n,
        now,
      ),
      'hours': [
        for (final h in hours)
          {
            'time': DateFormat.Hm(locale).format(h.time.toLocal()),
            'icon': iconKey(h.condition, snapshot.isDayAt(h.time)),
            'temp': units.temperatureText(h.temperature),
          },
      ],
      'days': [
        for (final d in days.take(_days))
          {
            'label': d.date == today
                ? l10n.weatherToday
                : DateFormat.E(locale).format(d.date),
            'icon': iconKey(d.condition, true),
            'high': units.temperatureText(d.maxTemperature),
            'low': units.temperatureText(d.minTemperature),
          },
      ],
      if (warning != null)
        'warning': {
          'text': warning.headline.isEmpty
              ? WeatherL10n.warningLevel(l10n, warning.level)
              : warning.headline,
          'color': WeatherColors.warning(warning.level).toARGB32(),
        },
    };
  }

  /// Lines beside the temperature on a wide widget, most useful first.
  static List<String> _details(
    CurrentConditions current,
    DailyForecast? today,
    WeatherSnapshot snapshot,
    WeatherUnits units,
    Set<WeatherWidgetDetail> shown,
    AppLocalizations l10n,
    DateTime now,
  ) {
    final hm = DateFormat.Hm(l10n.localeName);
    final sun = snapshot.sunTimes(now);
    return [
      if (shown.contains(WeatherWidgetDetail.feelsLike) &&
          current.feelsLike != null)
        l10n.weatherFeelsLike(units.temperatureText(current.feelsLike)),
      if (shown.contains(WeatherWidgetDetail.wind) && current.windSpeed != null)
        '${l10n.weatherWind} ${units.windText(current.windSpeed)}',
      if (shown.contains(WeatherWidgetDetail.rainChance) &&
          today?.precipitationProbability != null)
        '${l10n.weatherPrecipitationProbability} '
            '${WeatherUnits.percentText(today!.precipitationProbability)}',
      if (shown.contains(WeatherWidgetDetail.humidity) &&
          current.humidity != null)
        '${l10n.weatherHumidity} ${WeatherUnits.percentText(current.humidity)}',
      if (shown.contains(WeatherWidgetDetail.sun) &&
          sun.sunrise != null &&
          sun.sunset != null)
        '↑ ${hm.format(sun.sunrise!.toLocal())}  '
            '↓ ${hm.format(sun.sunset!.toLocal())}',
    ];
  }

  /// Matches the `weather_icon_<key>` drawables rendered from the app's icons.
  static String iconKey(WeatherCondition condition, bool isDay) {
    final name = condition.name.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    );
    return '${name}_${isDay ? 'd' : 'n'}';
  }

  static String theme(WeatherCondition condition, bool isDay) {
    if (condition == WeatherCondition.thunderstorm ||
        condition == WeatherCondition.hail) {
      return 'storm';
    }
    if (!isDay) return 'night';
    return switch (condition) {
      WeatherCondition.clear ||
      WeatherCondition.mostlyClear ||
      WeatherCondition.partlyCloudy => 'day',
      _ => 'gray',
    };
  }

  static Future<void> _writeWidget(Map<String, Object?> json) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'weather'));
    await dir.create(recursive: true);
    final tmp = File(p.join(dir.path, 'widget.json.tmp'));
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(p.join(dir.path, 'widget.json'));
  }
}
