import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/weather/api/station_catalog.dart';
import 'package:tool_lab/tools/weather/api/weather_http.dart';
import 'package:tool_lab/tools/weather/models/geo_place.dart';
import 'package:tool_lab/tools/weather/weather_db_helper.dart';
import 'package:tool_lab/tools/weather/weather_page.dart';
import 'package:tool_lab/tools/weather/weather_radar_state.dart';
import 'package:tool_lab/tools/weather/weather_repository.dart';
import 'package:tool_lab/tools/weather/weather_settings.dart';
import 'package:tool_lab/tools/weather/weather_state.dart';
import 'package:tool_lab/tools/weather/widgets/weather_hero.dart';
import 'package:tool_lab/tools/weather/widgets/weather_location_list.dart';

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
}
