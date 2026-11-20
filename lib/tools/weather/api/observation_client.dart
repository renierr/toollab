import 'dart:convert';

import '../models/weather_observation.dart';
import 'weather_http.dart';

class ObservationClient {
  const ObservationClient();

  static Uri url(String stationId) => Uri.https(
    'opendata.dwd.de',
    '/weather/weather_reports/poi/$stationId-BEOB.csv',
  );

  Future<ObservationSeries> fetch(String stationId) async {
    final bytes = await WeatherHttp.getBytes(url(stationId));
    return parseCsv(utf8.decode(bytes, allowMalformed: true), stationId);
  }

  /// Row 1 holds the English parameter keys, rows 2–3 units and German labels.
  static ObservationSeries parseCsv(String csv, String stationId) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 4) {
      throw const WeatherException(WeatherError.invalidData);
    }
    final keys = lines.first.split(';');
    int col(String key) => keys.indexOf(key);

    final iTemp = col('dry_bulb_temperature_at_2_meter_above_ground');
    final iDew = col('dew_point_temperature_at_2_meter_above_ground');
    final iHum = col('relative_humidity');
    final iPress = col('pressure_reduced_to_mean_sea_level');
    final iWind = col(
      'mean_wind_speed_during last_10_min_at_10_meters_above_ground',
    );
    final iDir = col(
      'mean_wind_direction_during_last_10 min_at_10_meters_above_ground',
    );
    final iGust = col('maximum_wind_speed_last_hour');
    final iRain1 = col('precipitation_amount_last_hour');
    final iRain24 = col('precipitation_amount_last_24_hours');
    final iCloud = col('cloud_cover_total');
    final iVis = col('horizontal_visibility');
    final iSnow = col('total_snow_depth');
    final iSun = col('total_time_of_sunshine_during_last_hour');
    final iWeather = col('present_weather');

    final rows = <WeatherObservation>[];
    for (final line in lines.skip(3)) {
      final cells = line.split(';');
      if (cells.length < 2) continue;
      final time = _parseTime(cells[0], cells[1]);
      if (time == null) continue;
      double? num(int i) {
        if (i < 0 || i >= cells.length) return null;
        return double.tryParse(cells[i].trim().replaceAll(',', '.'));
      }

      double? kmh(int i) => num(i) == null ? null : num(i)! / 3.6;
      rows.add(
        WeatherObservation(
          time: time,
          temperature: num(iTemp),
          dewPoint: num(iDew),
          humidity: num(iHum),
          pressure: num(iPress),
          windSpeed: kmh(iWind),
          windDirection: num(iDir),
          windGust: kmh(iGust),
          precipitation1h: num(iRain1),
          precipitation24h: num(iRain24),
          cloudCover: num(iCloud),
          visibility: num(iVis) == null ? null : num(iVis)! * 1000,
          snowDepth: num(iSnow),
          sunshineMinutes: num(iSun),
          presentWeather: num(iWeather)?.round(),
        ),
      );
    }
    return ObservationSeries(stationId: stationId, rows: rows);
  }

  static DateTime? _parseTime(String date, String time) {
    final d = date.trim().split('.');
    final t = time.trim().split(':');
    if (d.length != 3 || t.length != 2) return null;
    final day = int.tryParse(d[0]);
    final month = int.tryParse(d[1]);
    final year = int.tryParse(d[2]);
    final hour = int.tryParse(t[0]);
    final minute = int.tryParse(t[1]);
    if ([day, month, year, hour, minute].contains(null)) return null;
    return DateTime.utc(2000 + year!, month!, day!, hour!, minute!);
  }
}
