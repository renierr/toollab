// A hang should fail fast instead of after the 10-minute default.
@Timeout(Duration(minutes: 1))
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/widgets/health_chart_tooltip.dart';
import 'package:tool_lab/tools/weather/api/station_catalog.dart';
import 'package:tool_lab/tools/weather/api/weather_http.dart';
import 'package:tool_lab/tools/weather/models/geo_place.dart';
import 'package:tool_lab/tools/weather/weather_db_helper.dart';
import 'package:tool_lab/tools/weather/weather_page.dart';
import 'package:tool_lab/tools/weather/weather_radar_state.dart';
import 'package:tool_lab/tools/weather/weather_repository.dart';
import 'package:tool_lab/tools/weather/weather_settings.dart';
import 'package:tool_lab/tools/weather/weather_state.dart';
import 'package:tool_lab/tools/weather/models/weather_condition.dart';
import 'package:tool_lab/tools/weather/models/weather_history_entry.dart';
import 'package:tool_lab/tools/weather/weather_history_page.dart';
import 'package:tool_lab/tools/weather/weather_history_store.dart';
import 'package:tool_lab/tools/weather/widgets/weather_history_chart.dart';
import 'package:tool_lab/tools/weather/widgets/weather_history_stats.dart';
import 'package:tool_lab/tools/weather/widgets/weather_hero.dart';
import 'package:tool_lab/tools/weather/widgets/weather_location_list.dart';
import 'package:tool_lab/tools/weather/widgets/weather_settings_page.dart';

const _fixtures = 'test/fixtures/weather';

Future<Uint8List> _fetch(
  Uri uri, {
  Map<String, String> headers = const {},
}) async {
  final file = switch (uri.host) {
    'opendata.dwd.de' when uri.path.endsWith('.kmz') => 'mosmix_L841.kmz',
    'opendata.dwd.de' => 'beob_10637.csv',
    'app-prod-ws.warnwetter.de' => 'warnwetter_L841.json',
    's3.eu-central-1.amazonaws.com' => 'warnings_nowcast.json.gz',
    _ => throw const WeatherException(WeatherError.notFound),
  };
  return File('$_fixtures/$file').readAsBytesSync();
}

void main() {
  late WeatherState state;
  final history = _MemoryHistory();
  late WeatherRadarState radar;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    WeatherDbHelper.instance.reset();
    final catalog = StationCatalog.fromJson(
      File(StationCatalog.assetPath).readAsStringSync(),
    );
    state = WeatherState(
      repository: WeatherRepository(fetch: _fetch),
      catalogLoader: () async => catalog,
      settingsLoader: () async => const WeatherSettings(animatedIcons: false),
      historyStore: history,
    );
    radar = WeatherRadarState(
      fetch: (_) async =>
          throw const WeatherException(WeatherError.unreachable),
    );
    await state.ensureLoaded();
    final eschborn = await state.addPlace(
      const GeoPlace(
        name: 'Eschborn',
        label: 'Eschborn',
        latitude: 50.15,
        longitude: 8.56,
      ),
    );
    await state.pinStations(eschborn.id!, forecast: 'L841');
    await state.addPlace(
      const GeoPlace(
        name: 'Frankfurt am Main',
        label: 'Frankfurt',
        latitude: 50.11,
        longitude: 8.68,
      ),
    );
    await state.refreshAll();
    state.select(eschborn.id!);
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  Future<void> pumpAt(WidgetTester tester, Size size, Locale locale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WeatherState>.value(value: state),
          ChangeNotifierProvider<WeatherRadarState>.value(value: radar),
        ],
        child: MaterialApp.router(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: const [Locale('en'), Locale('de')],
          routerConfig: GoRouter(
            initialLocation: '/weather',
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SizedBox()),
              GoRoute(path: '/weather', builder: (_, _) => const WeatherPage()),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final (name, size) in const [
    ('phone', Size(360, 780)),
    ('small phone', Size(320, 640)),
    ('tablet', Size(820, 1100)),
    ('desktop', Size(1440, 900)),
  ]) {
    for (final locale in const [Locale('de'), Locale('en')]) {
      testWidgets(
        'renders without overflow on $name (${locale.languageCode})',
        (tester) async {
          await pumpAt(tester, size, locale);
          expect(find.byType(WeatherHero), findsOneWidget);
          expect(
            find.byType(WeatherLocationList),
            size.width >= 720 ? findsOneWidget : findsNothing,
          );
          final scrollable = find.byType(Scrollable).first;
          await tester.drag(scrollable, const Offset(0, -2000));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final locale in const [Locale('de'), Locale('en')]) {
    testWidgets('settings page opens and fits a small phone '
        '(${locale.languageCode})', (tester) async {
      await pumpAt(tester, const Size(320, 640), locale);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byType(WeatherSettingsPage), findsOneWidget);
      final scrollable = find.byType(Scrollable).last;
      await tester.drag(scrollable, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (name, size) in const [
    ('small phone', Size(320, 640)),
    ('desktop', Size(1440, 900)),
  ]) {
    testWidgets('history page fits a $name in every period', (tester) async {
      final id = state.locations.first.id!;
      final now = DateTime.now();
      history.entries.addAll([
        for (var h = 0; h < 24 * 10; h++)
          WeatherHistoryEntry(
            locationId: id,
            hour: WeatherHistoryEntry.hourOf(
              now.subtract(Duration(hours: h + 1)),
            ),
            source: WeatherHistorySource.measured,
            temperature: 5 + (h % 24) / 3,
            precipitation: h % 7 == 0 ? 1.2 : 0,
            windGust: 12,
            sunshineMinutes: 20,
            condition: WeatherCondition.rain,
          ),
      ]);
      await pumpAt(tester, size, const Locale('de'));
      Future<void> settle() => tester.pumpAndSettle();

      final navigator = Navigator.of(tester.element(find.byType(WeatherPage)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => WeatherHistoryPage(locationId: id),
          ),
        ),
      );
      await settle();
      expect(find.byType(WeatherHistoryStats), findsOneWidget);
      // The readout appears on tap and hides itself again.
      await tester.tap(find.byType(WeatherHistoryChart));
      await tester.pump();
      expect(find.byType(HealthChartTooltip), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(HealthChartTooltip), findsNothing);
      for (final label in ['Tag', 'Monat', 'Jahr', 'Woche']) {
        await tester.tap(find.text(label));
        await settle();
        final scrollable = find.byType(Scrollable).last;
        await tester.drag(scrollable, const Offset(0, -2000));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(scrollable, const Offset(0, 2000));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _MemoryHistory extends WeatherHistoryStore {
  final List<WeatherHistoryEntry> entries = [];

  @override
  Future<List<WeatherHistoryEntry>> hours(
    int locationId,
    DateTime from,
    DateTime to,
  ) async => [
    for (final e in entries)
      if (e.locationId == locationId &&
          !e.hour.isBefore(from) &&
          e.hour.isBefore(to))
        e,
  ]..sort((a, b) => a.hour.compareTo(b.hour));

  @override
  Future<int> count() async => entries.length;

  @override
  Future<void> clear() async => entries.clear();
}
