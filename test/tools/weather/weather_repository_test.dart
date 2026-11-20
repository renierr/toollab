import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/weather/api/observation_client.dart';
import 'package:tool_lab/tools/weather/api/station_catalog.dart';
import 'package:tool_lab/tools/weather/api/weather_http.dart';
import 'package:tool_lab/tools/weather/models/geo_place.dart';
import 'package:tool_lab/tools/weather/models/weather_location.dart';
import 'package:tool_lab/tools/weather/weather_db_helper.dart';
import 'package:tool_lab/tools/weather/weather_repository.dart';
import 'package:tool_lab/tools/weather/weather_settings.dart';
import 'package:tool_lab/tools/weather/weather_state.dart';

const _fixtures = 'test/fixtures/weather';

class _FakeNetwork {
  bool offline = false;
  final Set<String> missing = {};
  final List<Uri> requests = [];

  Future<Uint8List> fetch(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requests.add(uri);
    if (offline) throw const WeatherException(WeatherError.unreachable);
    if (missing.any(uri.path.contains)) {
      throw const WeatherException(WeatherError.notFound);
    }
    final file = switch (uri.host) {
      'opendata.dwd.de' when uri.path.endsWith('.kmz') => 'mosmix_L841.kmz',
      'opendata.dwd.de' => 'beob_10637.csv',
      'app-prod-ws.warnwetter.de' => 'warnwetter_L841.json',
      _ => throw const WeatherException(WeatherError.notFound),
    };
    return File('$_fixtures/$file').readAsBytesSync();
  }
}

void main() {
  late StationCatalog catalog;
  late DateTime now;
  const eschborn = WeatherLocation(
    id: 1,
    name: 'Eschborn',
    latitude: 50.150,
    longitude: 8.561,
    forecastStationId: 'L841',
  );

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

  group('WeatherRepository', () {
    test('combines forecast, live measurement and warnings', () async {
      final net = _FakeNetwork();
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      final snapshot = await repo.load(eschborn, catalog);

      expect(snapshot.forecastStation!.station.id, 'L841');
      expect(snapshot.observationStation!.station.hasObservations, isTrue);
      expect(snapshot.forecast!.hours, isNotEmpty);
      expect(snapshot.current(now)!.isMeasured, isTrue);
      expect(snapshot.overview!.warnings, isNotEmpty);
      expect(snapshot.error, isNull);
      expect(snapshot.isStale, isFalse);
    });

    test('serves fresh cache without network', () async {
      final net = _FakeNetwork();
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      await repo.load(eschborn, catalog);
      net
        ..requests.clear()
        ..offline = true;
      final snapshot = await repo.load(eschborn, catalog);
      expect(net.requests, isEmpty);
      expect(snapshot.forecast, isNotNull);
    });

    test('falls back to stale cache when a forced refresh fails', () async {
      final net = _FakeNetwork();
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      await repo.load(eschborn, catalog);
      net.offline = true;
      final snapshot = await repo.load(eschborn, catalog, force: true);
      expect(snapshot.forecast, isNotNull);
      expect(snapshot.isStale, isTrue);
      expect(snapshot.error, WeatherError.unreachable);
    });

    test('tries the next forecast station when one is missing', () async {
      final net = _FakeNetwork();
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      const auto = WeatherLocation(
        id: 2,
        name: 'Eschborn',
        latitude: 50.150,
        longitude: 8.561,
      );
      final first = catalog
          .nearest(auto.latitude, auto.longitude)
          .first
          .station
          .id;
      net.missing.add('/$first/');
      final snapshot = await repo.load(auto, catalog, force: true);
      expect(snapshot.forecastStation!.station.id, isNot(first));
      expect(snapshot.forecast, isNotNull);
    });

    test('reports missing data when every source fails', () async {
      final net = _FakeNetwork()..offline = true;
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      const nowhere = WeatherLocation(
        id: 3,
        name: 'Sea',
        latitude: 30,
        longitude: -40,
      );
      final snapshot = await repo.load(nowhere, catalog);
      expect(snapshot.hasData, isFalse);
      expect(snapshot.error, isNotNull);
    });
  });

  group('WeatherState', () {
    late WeatherState state;

    setUp(() async {
      WeatherDbHelper.instance.reset();
      final db = await DatabaseService.instance.getToolDatabase('weather');
      await db.migrate(currentVersion: 1, onMigrate: (_, _, _) async {});
      for (final l in await WeatherDbHelper.instance.getLocations()) {
        await WeatherDbHelper.instance.deleteLocation(l.id!);
      }
      final net = _FakeNetwork();
      state = WeatherState(
        repository: WeatherRepository(fetch: net.fetch, clock: () => now),
        catalogLoader: () async => catalog,
        settingsLoader: () async => const WeatherSettings(),
      );
      await state.ensureLoaded();
    });

    tearDown(() => state.dispose());

    const place = GeoPlace(
      name: 'Eschborn',
      label: 'Eschborn, Hessen',
      latitude: 50.15,
      longitude: 8.56,
    );
    const other = GeoPlace(
      name: 'Berlin',
      label: 'Berlin',
      latitude: 52.52,
      longitude: 13.40,
    );

    test('adding a place selects and loads it', () async {
      final added = await state.addPlace(place);
      expect(state.selected!.id, added.id);
      await state.refresh(added.id!);
      expect(state.snapshotFor(added.id)!.forecast, isNotNull);
    });

    test('remove and undo keep the original position', () async {
      final a = await state.addPlace(place);
      await state.addPlace(other);
      final removed = await state.removeLocation(a.id!);
      expect(state.locations.map((l) => l.name), ['Berlin']);
      await state.restoreLocation(removed!);
      expect(state.locations.map((l) => l.name), ['Eschborn', 'Berlin']);
      final stored = await WeatherDbHelper.instance.getLocations();
      expect(stored.map((l) => l.name), ['Eschborn', 'Berlin']);
    });

    test('default location wins over list order', () async {
      await state.addPlace(place);
      final berlin = await state.addPlace(other);
      await state.setDefault(berlin.id);
      expect(state.defaultLocation!.name, 'Berlin');
      await state.removeLocation(berlin.id!);
      expect(state.settings.defaultLocationId, isNull);
      expect(state.defaultLocation!.name, 'Eschborn');
    });

    test('pinned stations persist and can be cleared', () async {
      final a = await state.addPlace(place);
      await state.pinStations(a.id!, forecast: 'L841', observation: '10637');
      var stored = (await WeatherDbHelper.instance.getLocations()).single;
      expect(stored.forecastStationId, 'L841');
      expect(stored.observationStationId, '10637');
      await state.pinStations(a.id!);
      stored = (await WeatherDbHelper.instance.getLocations()).single;
      expect(stored.forecastStationId, isNull);
    });

    test('rename and reorder persist', () async {
      final a = await state.addPlace(place);
      await state.addPlace(other);
      await state.rename(a.id!, '  Zuhause ');
      await state.reorder(0, 1);
      final stored = await WeatherDbHelper.instance.getLocations();
      expect(stored.map((l) => l.name), ['Berlin', 'Zuhause']);
    });
  });
}
