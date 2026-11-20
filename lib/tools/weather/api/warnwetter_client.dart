import 'dart:convert';

import '../models/day_astronomy.dart';
import '../models/station_overview.dart';
import '../models/weather_warning.dart';
import 'weather_http.dart';

/// Backend of the DWD WarnWetter app: sun/moon per day and warnings per station.
class WarnwetterClient {
  const WarnwetterClient();

  static Uri url(Iterable<String> stationIds) => Uri.https(
    'app-prod-ws.warnwetter.de',
    '/v30/stationOverviewExtended',
    {'stationIds': stationIds.join(',')},
  );

  Future<Map<String, StationOverview>> fetch(
    Iterable<String> stationIds,
  ) async {
    final bytes = await WeatherHttp.getBytes(
      url(stationIds),
      headers: const {'Accept': 'application/json'},
    );
    return parse(utf8.decode(bytes));
  }

  static Map<String, StationOverview> parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const WeatherException(WeatherError.invalidData);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WeatherException(WeatherError.invalidData);
    }
    return {
      for (final entry in decoded.entries)
        if (entry.value is Map<String, dynamic>)
          entry.key: _station(entry.value as Map<String, dynamic>),
    };
  }

  static StationOverview _station(Map<String, dynamic> json) {
    final days = <DayAstronomy>[];
    for (final d in json['days'] as List<dynamic>? ?? const []) {
      if (d is Map<String, dynamic> && d['dayDate'] is String) {
        days.add(DayAstronomy.fromJson(d));
      }
    }
    final warnings = <WeatherWarning>[];
    for (final w in json['warnings'] as List<dynamic>? ?? const []) {
      if (w is Map<String, dynamic> && w['start'] is num) {
        warnings.add(WeatherWarning.fromJson(w));
      }
    }
    warnings.sort((a, b) => b.level.compareTo(a.level));
    return StationOverview(days: days, warnings: warnings);
  }
}
