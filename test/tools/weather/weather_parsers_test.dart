import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/weather/api/geocoding_client.dart';
import 'package:tool_lab/tools/weather/api/mosmix_client.dart';
import 'package:tool_lab/tools/weather/api/nowcast_client.dart';
import 'package:tool_lab/tools/weather/api/observation_client.dart';
import 'package:tool_lab/tools/weather/api/warnwetter_client.dart';
import 'package:tool_lab/tools/weather/api/weather_http.dart';
import 'package:tool_lab/tools/weather/models/weather_condition.dart';

const _fixtures = 'test/fixtures/weather';

void main() {
  group('MosmixClient', () {
    final forecast = MosmixClient.parseKmz(
      File('$_fixtures/mosmix_L841.kmz').readAsBytesSync(),
      'L841',
    );

    test('reads ten days of hourly steps', () {
      expect(forecast.hours.length, 247);
      expect(forecast.issueTime, DateTime.utc(2026, 11, 20, 9));
      expect(forecast.hours.first.time, DateTime.utc(2026, 11, 20, 10));
    });

    test('converts units to °C, hPa and m/s', () {
      final h = forecast.hours.first;
      expect(h.temperature, inInclusiveRange(-30, 40));
      expect(h.pressure, inInclusiveRange(950, 1060));
      expect(h.windSpeed, inInclusiveRange(0, 60));
      expect(h.precipitationProbability, inInclusiveRange(0, 100));
      expect(h.humidity, inInclusiveRange(0, 100));
      expect(h.weatherCode, 61);
      expect(h.condition, WeatherCondition.lightRain);
    });

    test('aggregates local days with min below max', () {
      expect(forecast.days.length, greaterThanOrEqualTo(9));
      for (final d in forecast.days) {
        expect(d.minTemperature! <= d.maxTemperature!, isTrue);
      }
    });

    test('rejects garbage', () {
      expect(
        () => MosmixClient.parseKmz(
          File('$_fixtures/beob_10637.csv').readAsBytesSync(),
          'x',
        ),
        throwsA(isA<WeatherException>()),
      );
    });
  });

  group('ObservationClient', () {
    final series = ObservationClient.parseCsv(
      File('$_fixtures/beob_10637.csv').readAsStringSync(),
      '10637',
    );

    test('parses newest row first with decimal commas', () {
      expect(series.rows, isNotEmpty);
      final latest = series.latest!;
      expect(latest.time.isUtc, isTrue);
      expect(latest.time.isAfter(series.rows.last.time), isTrue);
      expect(latest.temperature, isNotNull);
      expect(latest.pressure, inInclusiveRange(950, 1060));
      expect(latest.humidity, inInclusiveRange(0, 100));
    });

    test('treats --- as missing', () {
      expect(series.rows.any((r) => r.cloudCover == null), isTrue);
    });
  });

  test('WarnwetterClient reads days and warnings', () {
    final result = WarnwetterClient.parse(
      File('$_fixtures/warnwetter_L841.json').readAsStringSync(),
    );
    final station = result['L841']!;
    expect(station.days, hasLength(3));
    expect(station.days.first.sunrise, isNotNull);
    expect(station.days.first.moonPhase, inInclusiveRange(0, 7));
    expect(station.warnings.first.headline, contains('FROST'));
    expect(station.warnings.first.level, 2);
  });

  test('GeocodingClient finds Eschborn', () {
    final places = GeocodingClient.parse(
      File('$_fixtures/nominatim_eschborn.json').readAsStringSync(),
    );
    expect(places.first.name, 'Eschborn');
    expect(places.first.latitude, closeTo(50.15, 0.02));
    expect(places.first.longitude, closeTo(8.56, 0.02));
  });

  group('WeatherCondition', () {
    test('ww cloud codes fall back to cloud cover', () {
      expect(WeatherCondition.fromWw(2, cloudCover: 5), WeatherCondition.clear);
      expect(
        WeatherCondition.fromWw(1, cloudCover: 95),
        WeatherCondition.overcast,
      );
    });

    test('ww precipitation codes', () {
      expect(WeatherCondition.fromWw(95), WeatherCondition.thunderstorm);
      expect(WeatherCondition.fromWw(73), WeatherCondition.snow);
      expect(WeatherCondition.fromWw(81), WeatherCondition.rainShower);
      expect(WeatherCondition.fromWw(45), WeatherCondition.fog);
    });

    test('DWD icon codes', () {
      expect(WeatherCondition.fromDwdCode(8), WeatherCondition.rain);
      expect(WeatherCondition.fromDwdCode(27), WeatherCondition.thunderstorm);
      expect(WeatherCondition.fromDwdCode(32767), isNull);
    });
  });

  group('NowcastClient', () {
    final areas = NowcastClient.parse(
      File('$_fixtures/warnings_nowcast.json.gz').readAsBytesSync(),
    );

    test('reads gzip-compressed area warnings', () {
      expect(areas, hasLength(4));
      final w = areas.first.warning;
      expect(w.isNowcast, isTrue);
      expect(w.headline, 'Starkregen');
      expect(w.level, 3);
      expect(w.end!.isAfter(w.start), isTrue);
    });

    test('matches places by polygon', () {
      expect(areas.where((a) => a.contains(50.20, 8.58)), hasLength(1));
      expect(areas.where((a) => a.contains(50.150, 8.561)), isEmpty);
      expect(areas.where((a) => a.contains(52.52, 13.40)), isEmpty);
    });
  });
}
