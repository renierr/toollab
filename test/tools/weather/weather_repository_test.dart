import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/weather/models/weather_condition.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/weather/api/observation_client.dart';
import 'package:tool_lab/tools/weather/api/station_catalog.dart';
import 'package:tool_lab/tools/weather/api/weather_http.dart';
import 'package:tool_lab/tools/weather/models/geo_place.dart';
import 'package:tool_lab/tools/weather/models/weather_location.dart';
import 'package:tool_lab/tools/weather/models/weather_warning.dart';
import 'package:tool_lab/services/background_task_service.dart';
import 'package:tool_lab/tools/weather/weather_background.dart';
import 'package:tool_lab/tools/weather/weather_db_helper.dart';
import 'package:tool_lab/tools/weather/weather_publisher.dart';
import 'package:tool_lab/tools/weather/weather_repository.dart';
import 'package:tool_lab/tools/weather/weather_settings.dart';
import 'package:tool_lab/tools/weather/weather_state.dart';
import 'package:tool_lab/tools/weather/weather_warning_alerts.dart';

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
      's3.eu-central-1.amazonaws.com' => 'warnings_nowcast.json.gz',
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

    test('adds nowcast warnings only for places inside the area', () async {
      final net = _FakeNetwork();
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      final inside = await repo.load(
        eschborn.copyWith(latitude: 50.20, longitude: 8.58),
        catalog,
      );
      final nowcast = inside.warnings(now).where((w) => w.isNowcast);
      expect(nowcast, hasLength(1));
      expect(nowcast.single.event, 'Starkregen');
      final levels = inside.warnings(now).map((w) => w.level).toList();
      expect(levels, [...levels]..sort((a, b) => b.compareTo(a)));

      final outside = await repo.load(eschborn, catalog);
      expect(outside.warnings(now).where((w) => w.isNowcast), isEmpty);
    });

    test('falls back to a nearby station the warning service knows', () async {
      final net = _FakeNetwork();
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      final pinned = eschborn.withStations(forecast: 'K2561');
      final snapshot = await repo.load(pinned, catalog, force: true);
      expect(snapshot.forecastStation!.station.id, 'K2561');
      expect(snapshot.overview, isNotNull);
      expect(net.requests.last.queryParameters['stationIds'], contains('L841'));
    });

    test('cache-only answers from the database even when outdated', () async {
      final net = _FakeNetwork();
      await WeatherRepository(
        fetch: net.fetch,
        clock: () => now,
      ).load(eschborn, catalog, force: true);
      net
        ..requests.clear()
        ..offline = true;
      final later = WeatherRepository(
        fetch: net.fetch,
        clock: () => now.add(const Duration(days: 1)),
      );
      final snapshot = await later.load(eschborn, catalog, cacheOnly: true);
      expect(net.requests, isEmpty);
      expect(snapshot.forecast, isNotNull);
      expect(snapshot.fetchedAt.isAtSameMomentAs(now), isTrue);
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

  group('WeatherWarningAlerts', () {
    final start = DateTime.utc(2026, 11, 20, 15);
    WeatherWarning warning(String id, int level, {String event = 'GEWITTER'}) =>
        WeatherWarning(
          id: id,
          type: 0,
          level: level,
          start: start,
          end: start.add(const Duration(hours: 2)),
          event: event,
          headline: event,
          description: '',
          instruction: '',
        );

    test('announces each warning once, from the chosen level up', () async {
      final alerts = WeatherWarningAlerts();
      final now = start.subtract(const Duration(minutes: 10));
      final first = await alerts.takeNew(
        [warning('a', 1), warning('b', 2)],
        2,
        now,
      );
      expect(first.map((w) => w.id), ['b']);
      expect(await alerts.takeNew([warning('b', 2)], 2, now), isEmpty);
      // A new nowcast run renames the same warning.
      expect(await alerts.takeNew([warning('b2', 2)], 2, now), isEmpty);
      // An upgrade is news.
      expect(await alerts.takeNew([warning('b3', 3)], 2, now), hasLength(1));
      expect(
        await alerts.takeNew([warning('c', 2, event: 'FROST')], 2, now),
        hasLength(1),
      );
      expect(await alerts.takeNew([warning('d', 4)], 0, now), isEmpty);
    });

    test('forgets warnings once they have ended', () async {
      final alerts = WeatherWarningAlerts();
      final w = warning('late', 2, event: 'GLATTEIS');
      expect(await alerts.takeNew([w], 2, start), hasLength(1));
      final later = start.add(const Duration(hours: 3));
      final again = WeatherWarning(
        id: 'late2',
        type: 0,
        level: 2,
        start: later,
        end: later.add(const Duration(hours: 1)),
        event: 'GLATTEIS',
        headline: '',
        description: '',
        instruction: '',
      );
      expect(await alerts.takeNew([again], 2, later), hasLength(1));
    });
  });

  group('WeatherBackground', () {
    const a = WeatherLocation(id: 1, name: 'A', latitude: 50, longitude: 8);
    const b = WeatherLocation(id: 2, name: 'B', latitude: 52, longitude: 13);

    test('refreshes the default place or all places', () {
      const settings = WeatherSettings(defaultLocationId: 2);
      expect(WeatherBackground.targetsFor([a, b], settings), [b]);
      expect(WeatherBackground.targetsFor([a, b], const WeatherSettings()), [
        a,
      ]);
      expect(
        WeatherBackground.targetsFor(
          [a, b],
          settings.copyWith(backgroundScope: WeatherBackgroundScope.allPlaces),
        ),
        [a, b],
      );
      expect(WeatherBackground.targetsFor([], settings), isEmpty);
    });

    test('quiet hours wrap around midnight', () {
      const s = WeatherSettings(quietFrom: 23, quietTo: 6);
      expect(s.isQuietAt(DateTime(2026, 1, 1, 23, 30)), isTrue);
      expect(s.isQuietAt(DateTime(2026, 1, 1, 3)), isTrue);
      expect(s.isQuietAt(DateTime(2026, 1, 1, 6)), isFalse);
      expect(s.isQuietAt(DateTime(2026, 1, 1, 12)), isFalse);
      expect(
        s.copyWith(quietHours: false).isQuietAt(DateTime(2026, 1, 1, 3)),
        isFalse,
      );
      const day = WeatherSettings(quietFrom: 9, quietTo: 17);
      expect(day.isQuietAt(DateTime(2026, 1, 1, 12)), isTrue);
      expect(day.isQuietAt(DateTime(2026, 1, 1, 20)), isFalse);
    });

    test('a run refreshes the saved places and skips quiet hours', () async {
      WeatherDbHelper.instance.reset();
      final saved = await WeatherDbHelper.instance.saveLocation(eschborn);
      final net = _FakeNetwork();
      Future<BackgroundTaskResult> runAt(int hour) => WeatherBackground.run(
        repository: WeatherRepository(fetch: net.fetch, clock: () => now),
        catalogLoader: () async => catalog,
        settingsLoader: () async =>
            WeatherSettings(defaultLocationId: saved.id),
        clock: () => DateTime(2026, 11, 20, hour),
      );

      final quiet = await runAt(2);
      expect(quiet.outcome, BackgroundTaskOutcome.skipped);
      expect(net.requests, isEmpty);

      final result = await runAt(12);
      expect(result.outcome, BackgroundTaskOutcome.done);
      expect(result.detail, '1/1 places');
      expect(net.requests, isNotEmpty);

      net.offline = true;
      final offline = await runAt(12);
      expect(
        offline.outcome,
        BackgroundTaskOutcome.done,
        reason: 'cache fresh',
      );
    });
  });

  group('WeatherPublisher', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = lookupAppLocalizations(const Locale('de'));
      await initializeDateFormatting('de');
    });

    test('widget data is ready to show in the user\'s units', () async {
      final net = _FakeNetwork();
      final repo = WeatherRepository(fetch: net.fetch, clock: () => now);
      final inside = eschborn.copyWith(id: 7, latitude: 50.20, longitude: 8.58);
      final snapshots = {
        1: await repo.load(eschborn, catalog),
        7: await repo.load(inside, catalog),
      };
      final json = WeatherPublisher.widgetJson(
        locations: [eschborn, inside],
        snapshots: snapshots,
        settings: const WeatherSettings(defaultLocationId: 7),
        l10n: l10n,
        now: now,
      );
      expect(json['defaultId'], 7);
      final places = json['places']! as List;
      expect(places, hasLength(2));
      final first = places.first as Map<String, Object?>;
      expect(first['name'], 'Eschborn');
      expect(first['temp'], matches(RegExp(r'^-?\d+°$')));
      expect(first['icon'], matches(RegExp(r'^[a-z_]+_[dn]$')));
      expect(first['hours'], hasLength(5));
      expect((first['days']! as List).first, containsPair('label', 'Heute'));
      final warning = first['warning']! as Map<String, Object?>;
      expect(warning['text'], isNotEmpty);
      expect(warning['color'], isA<int>());

      final fahrenheit = WeatherPublisher.widgetJson(
        locations: [eschborn],
        snapshots: snapshots,
        settings: const WeatherSettings(
          temperatureUnit: TemperatureUnit.fahrenheit,
        ),
        l10n: l10n,
        now: now,
      );
      final f = (fahrenheit['places']! as List).single as Map<String, Object?>;
      expect(f['temp'], isNot(first['temp']));
    });

    test('icons and backgrounds follow condition and daylight', () {
      expect(
        WeatherPublisher.iconKey(WeatherCondition.partlyCloudy, false),
        'partly_cloudy_n',
      );
      expect(WeatherPublisher.theme(WeatherCondition.clear, true), 'day');
      expect(WeatherPublisher.theme(WeatherCondition.clear, false), 'night');
      expect(WeatherPublisher.theme(WeatherCondition.rain, true), 'gray');
      expect(
        WeatherPublisher.theme(WeatherCondition.thunderstorm, false),
        'storm',
      );
    });

    test('a notification names the place and fits an Android int colour', () {
      final w = WeatherWarning(
        id: 'x',
        type: 0,
        level: 4,
        start: DateTime.utc(2026, 11, 20, 15),
        end: DateTime.utc(2026, 11, 20, 18),
        event: 'ORKAN',
        headline: 'Amtliche Unwetterwarnung vor ORKANBÖEN',
        description: 'Es treten Orkanböen auf. ' * 40,
        instruction: '',
      );
      final n = WeatherPublisher.notification(
        w,
        place: 'Eschborn',
        placeId: 3,
        l10n: l10n,
      );
      expect(n['title'], 'Amtliche Unwetterwarnung vor ORKANBÖEN · Eschborn');
      expect(n['key'], 'x');
      expect(n['placeId'], 3);
      expect((n['body']! as String).length, lessThanOrEqualTo(401));
      final color = n['color']! as int;
      expect(color, inInclusiveRange(-0x80000000, 0x7FFFFFFF));
    });
  });
}
