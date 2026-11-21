// A hang should fail fast instead of after the 10-minute default.
@Timeout(Duration(minutes: 1))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/weather/api/local_station_client.dart';
import 'package:tool_lab/tools/weather/api/observation_client.dart';
import 'package:tool_lab/tools/weather/api/station_catalog.dart';
import 'package:tool_lab/tools/weather/api/weather_http.dart';
import 'package:tool_lab/tools/weather/models/local_station_manifest.dart';
import 'package:tool_lab/tools/weather/models/weather_condition.dart';
import 'package:tool_lab/tools/weather/models/weather_location.dart';
import 'package:tool_lab/tools/weather/weather_db_helper.dart';
import 'package:tool_lab/tools/weather/weather_repository.dart';
import 'package:tool_lab/tools/weather/weather_settings.dart';
import 'package:tool_lab/tools/weather/weather_state.dart';

const _fixtures = 'test/fixtures/weather';
const _host = 'station.test';
final Uri _manifestUrl = Uri.http(_host, '/wx/weather-station.json');

Uint8List _json(Object value) => utf8.encode(jsonEncode(value));

/// Serves the DWD fixtures plus a local station built around [now].
class _FakeNetwork {
  _FakeNetwork(this.now, {this.sections = LocalStationSection.values});

  final DateTime now;
  final List<LocalStationSection> sections;
  bool stationOffline = false;
  final List<Uri> requests = [];

  Map<String, Object> get manifest => {
    'api': LocalStationClient.apiName,
    'version': 1,
    'station': {
      'id': 'garden',
      'name': 'Garden',
      'latitude': 50.150,
      'longitude': 8.561,
      'elevation': 140,
    },
    if (sections.contains(LocalStationSection.observations))
      'observations': {
        'url': 'observations.json',
        'fields': ['temperature', 'humidity', 'condition'],
      },
    if (sections.contains(LocalStationSection.forecast))
      'forecast': {
        'url': '/wx/forecast.json',
        'refreshSeconds': 10,
        'fields': ['temperature', 'precipitationProbability', 'condition'],
      },
    if (sections.contains(LocalStationSection.warnings))
      'warnings': {'url': 'warnings.json'},
    if (sections.contains(LocalStationSection.days))
      'days': {
        'url': 'days.json',
        'fields': ['sunrise', 'sunset'],
      },
  };

  Uint8List _local(String path) {
    final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
    return switch (path) {
      '/wx/weather-station.json' => _json(manifest),
      '/wx/observations.json' => _json({
        'rows': [
          {
            'time': hour.subtract(const Duration(hours: 1)).toIso8601String(),
            'temperature': 5.0,
          },
          {
            'time': now.subtract(const Duration(minutes: 5)).toIso8601String(),
            'temperature': 7.5,
            'humidity': 80,
            'pressure': 999,
            'condition': 'lightRain',
          },
          {'time': hour.toIso8601String(), 'temperature': 7.0},
        ],
      }),
      '/wx/forecast.json' => _json({
        'hours': [
          for (var h = 1; h <= 72; h++)
            {
              'time': hour.add(Duration(hours: h)).toIso8601String(),
              'temperature': 10 + h % 5,
              'precipitationProbability': 30,
              'condition': 'cloudy',
              'windSpeed': 99,
            },
        ],
      }),
      '/wx/warnings.json' => _json({
        'warnings': [
          {
            'id': 'frost-1',
            'level': 2,
            'start': now.toIso8601String(),
            'end': now.add(const Duration(hours: 8)).toIso8601String(),
            'event': 'Frost',
          },
        ],
      }),
      '/wx/days.json' => _json({
        'days': [
          {
            'date':
                '${now.year}-${now.month.toString().padLeft(2, '0')}'
                '-${now.day.toString().padLeft(2, '0')}',
            'sunrise': DateTime(
              now.year,
              now.month,
              now.day,
              7,
              30,
            ).toUtc().toIso8601String(),
            'sunset': DateTime(
              now.year,
              now.month,
              now.day,
              16,
              45,
            ).toUtc().toIso8601String(),
          },
        ],
      }),
      _ => throw const WeatherException(WeatherError.notFound),
    };
  }

  Future<Uint8List> fetch(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requests.add(uri);
    if (uri.host == _host) {
      if (stationOffline) {
        throw const WeatherException(WeatherError.unreachable);
      }
      return _local(uri.path);
    }
    final file = switch (uri.host) {
      'opendata.dwd.de' when uri.path.endsWith('.kmz') => 'mosmix_L841.kmz',
      'opendata.dwd.de' => 'beob_10637.csv',
      'app-prod-ws.warnwetter.de' => 'warnwetter_L841.json',
      's3.eu-central-1.amazonaws.com' => 'warnings_nowcast.json.gz',
      _ => throw const WeatherException(WeatherError.notFound),
    };
    return File('$_fixtures/$file').readAsBytesSync();
  }
}

void main() {
  late StationCatalog catalog;
  late DateTime now;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    catalog = StationCatalog.fromJson(
      File(StationCatalog.assetPath).readAsStringSync(),
    );
    final obs = ObservationClient.parseCsv(
      File('$_fixtures/beob_10637.csv').readAsStringSync(),
      '10637',
    );
    now = obs.latest!.time.add(const Duration(minutes: 30));
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  WeatherLocation place({int? id}) => WeatherLocation(
    id: id,
    name: 'Garden',
    latitude: 50.150,
    longitude: 8.561,
    stationUrl: _manifestUrl.toString(),
  );

  group('LocalStationClient', () {
    test('turns an address into the manifest URL', () {
      String? url(String s) => LocalStationClient.manifestUrl(s)?.toString();
      expect(
        url('192.168.1.50:8080'),
        'http://192.168.1.50:8080/weather-station.json',
      );
      expect(
        url('https://example.org/garden'),
        'https://example.org/garden/weather-station.json',
      );
      expect(url('http://host/x/'), 'http://host/x/weather-station.json');
      expect(
        url('http://host/api/station.json'),
        'http://host/api/station.json',
      );
      expect(url('ftp://host'), isNull);
      expect(url('  '), isNull);
    });

    test('parses the manifest and resolves section URLs', () {
      final net = _FakeNetwork(now);
      final m = LocalStationClient.parseManifest(
        _json(net.manifest),
        _manifestUrl,
      );
      expect(m.name, 'Garden');
      expect(m.elevation, 140);
      expect(m.sections.keys, LocalStationSection.values);
      expect(
        m[LocalStationSection.observations]!.url.toString(),
        'http://$_host/wx/observations.json',
      );
      expect(
        m[LocalStationSection.forecast]!.maxAge,
        const Duration(minutes: 1),
      );
      expect(
        m[LocalStationSection.observations]!.maxAge,
        LocalStationSection.observations.defaultMaxAge,
      );
      expect(m.station.isLocal, isTrue);
    });

    test('rejects foreign, newer and empty manifests', () {
      final net = _FakeNetwork(now);
      final invalid = throwsA(
        isA<WeatherException>().having(
          (e) => e.error,
          'error',
          WeatherError.invalidData,
        ),
      );
      expect(
        () => LocalStationClient.parseManifest(
          _json({...net.manifest, 'api': 'x'}),
          _manifestUrl,
        ),
        invalid,
      );
      expect(
        () => LocalStationClient.parseManifest(
          _json({...net.manifest, 'version': 2}),
          _manifestUrl,
        ),
        throwsA(isA<LocalStationVersionException>()),
      );
      expect(
        () => LocalStationClient.parseManifest(
          _json(
            _FakeNetwork(
              now,
              sections: [LocalStationSection.warnings],
            ).manifest,
          ),
          _manifestUrl,
        ),
        invalid,
      );
      expect(
        () => LocalStationClient.parseManifest(
          utf8.encode('<html>'),
          _manifestUrl,
        ),
        invalid,
      );
    });

    test('reads only declared fields, newest row first', () {
      final net = _FakeNetwork(now);
      final series = LocalStationClient.parseObservations(
        net._local('/wx/observations.json'),
        'garden',
        {'temperature', 'condition'},
      )!;
      expect(series.rows, hasLength(3));
      expect(series.latest!.temperature, 7.5);
      expect(series.latest!.humidity, isNull);
      expect(series.latest!.pressure, isNull);
      expect(series.latest!.condition, WeatherCondition.lightRain);
      expect(
        LocalStationClient.parseObservations(_json({'rows': []}), 'garden', {}),
        isNull,
      );
    });
  });

  group('WeatherRepository with a local station', () {
    setUp(WeatherDbHelper.instance.clearCache);

    test('takes every offered section from the station', () async {
      final net = _FakeNetwork(now);
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      final saved = await WeatherDbHelper.instance.saveLocation(place());
      final snapshot = await repo.load(saved, catalog, force: true);

      expect(snapshot.observationStation!.station.isLocal, isTrue);
      expect(snapshot.forecastStation!.station.isLocal, isTrue);
      expect(snapshot.current(now)!.temperature, 7.5);
      expect(snapshot.current(now)!.condition, WeatherCondition.lightRain);
      expect(snapshot.forecast!.hours.first.windSpeed, isNull);
      expect(snapshot.overview!.warnings.single.event, 'Frost');
      expect(snapshot.sunTimes(now).sunrise!.toLocal().hour, 7);
      expect(snapshot.isStale, isFalse);
      expect(net.requests.where((u) => u.host == 'opendata.dwd.de'), isEmpty);
      expect(
        net.requests.where((u) => u.host == 'app-prod-ws.warnwetter.de'),
        isEmpty,
      );

      final rows = await WeatherDbHelper.instance.getHistory(
        saved.id!,
        now.subtract(const Duration(hours: 3)),
        now.add(const Duration(hours: 1)),
      );
      expect(rows.where((r) => r.isMeasured).map((r) => r.temperature), [
        5.0,
        7.0,
      ]);
    });

    test('fills missing sections from the DWD', () async {
      final net = _FakeNetwork(
        now,
        sections: [LocalStationSection.observations],
      );
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      final snapshot = await repo.load(place(), catalog, force: true);

      expect(snapshot.observationStation!.station.isLocal, isTrue);
      expect(snapshot.forecastStation!.station.isLocal, isFalse);
      expect(snapshot.forecast!.hours, isNotEmpty);
      expect(snapshot.overview!.warnings, isNotEmpty);
      expect(snapshot.current(now)!.temperature, 7.5);
    });

    test(
      'an unreachable station falls back to the DWD and shows offline',
      () async {
        final net = _FakeNetwork(now)..stationOffline = true;
        final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
        final snapshot = await repo.load(place(), catalog, force: true);

        expect(snapshot.hasData, isTrue);
        expect(snapshot.observationStation?.station.isLocal ?? false, isFalse);
        expect(snapshot.forecastStation!.station.isLocal, isFalse);
        expect(snapshot.isStale, isTrue);
      },
    );

    test('serves the last station data from the cache when offline', () async {
      final net = _FakeNetwork(now);
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      await repo.load(place(), catalog, force: true);
      net.stationOffline = true;
      final snapshot = await repo.load(place(), catalog, force: true);

      expect(snapshot.observationStation!.station.isLocal, isTrue);
      expect(snapshot.current(now)!.temperature, 7.5);
      expect(snapshot.isStale, isTrue);
    });
  });

  group('WeatherState', () {
    test('adds a local station once', () async {
      final net = _FakeNetwork(now);
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      final state = WeatherState(
        repository: repo,
        catalogLoader: () async => catalog,
        settingsLoader: () async => const WeatherSettings(),
      );
      addTearDown(state.dispose);
      await state.ensureLoaded();

      final manifest = await state.inspectLocalStation(_manifestUrl);
      final added = await state.addLocalStation(manifest);
      expect(added.isLocalStation, isTrue);
      expect(added.name, 'Garden');
      await state.refresh(added.id!);
      expect(
        state.snapshotFor(added.id)!.observationStation!.station.isLocal,
        isTrue,
      );

      final again = await state.addLocalStation(manifest);
      expect(again.id, added.id);
      final stored = await WeatherDbHelper.instance.getLocations();
      expect(
        stored.where((l) => l.stationUrl == _manifestUrl.toString()),
        hasLength(1),
      );
    });
  });
}
