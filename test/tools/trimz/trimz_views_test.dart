import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/l10n/app_localization_delegates.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/trimz/trimz_api.dart';
import 'package:tool_lab/tools/trimz/trimz_state.dart';
import 'package:tool_lab/tools/trimz/widgets/trimz_browse_view.dart';

Map<String, dynamic> _card(int i) => {
  'project_id': 'p$i',
  'slug': 'series-$i',
  'title': 'A rather long series title number $i that needs two lines',
  'summary': 'A shy gamer gets stuck in a fake marriage.',
  'owner_display_name': 'Owner',
  'episode_count': 280,
  'total_views': 689819,
  'card_badges': [
    {'text': 'New Episodes'},
  ],
};

Object _answer(Uri uri) => switch (uri.path) {
  '/api/ms/explore-genres' => {
    'genres': [
      {'genre': 'romance', 'label': 'Romance'},
      {'genre': 'horror', 'label': 'Horror'},
    ],
  },
  '/api/ms/explore-feed' => {
    'sections': [
      {
        'id': 'trending',
        'title': 'Top 10 Today',
        'sectionType': 'ranked_carousel',
        'items': [for (var i = 0; i < 10; i++) _card(i)],
      },
      {
        'id': 'latest',
        'title': 'Latest',
        'sectionType': 'infinite_scroll',
        'items': [for (var i = 10; i < 22; i++) _card(i)],
      },
    ],
  },
  _ => {
    'projectId': 'p0',
    'slug': 'series-0',
    'title': 'A rather long series title number 0 that needs two lines',
    'summary': 'A shy gamer gets stuck in a fake marriage.',
    'ownerDisplayName': 'Owner',
    'totalViews': 689819,
    'videos': [
      for (var i = 0; i < 30; i++)
        {
          'shotId': 's$i',
          'order': i,
          'url': 'https://cdn.example/$i.mp4',
          'muxPlaybackUrl': 'https://stream.example/$i.m3u8',
          'durationSec': 57.5,
        },
    ],
  },
};

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  TrimzState newState() => TrimzState(
    api: TrimzApi(
      client: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(jsonEncode(_answer(request.url))),
          200,
        ),
      ),
    ),
  );

  Future<TrimzState> pumpBrowse(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = newState();
    await tester.runAsync(state.init);
    addTearDown(() => tester.runAsync(state.clearHistory));
    await tester.pumpWidget(
      ChangeNotifierProvider<TrimzState>.value(
        value: state,
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TrimzBrowseView()),
        ),
      ),
    );
    await tester.pump();
    return state;
  }

  for (final size in [const Size(360, 740), const Size(1400, 900)]) {
    testWidgets('catalog and series page lay out at $size', (tester) async {
      final state = await pumpBrowse(tester, size);
      expect(find.text('Top 10 Today'), findsOneWidget);
      expect(find.text('Romance'), findsOneWidget);

      await tester.tap(find.text(_card(0)['title'] as String).first);
      await tester.runAsync(() => state.loadSeries('series-0'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);

      await tester.runAsync(
        () => state.recordProgress(
          state.sections.first.items.first,
          episodeIndex: 3,
          episodeCount: 30,
          position: const Duration(seconds: 20),
          duration: const Duration(seconds: 57),
        ),
      );
      await tester.pump();
      expect(find.text('Continue episode 4'), findsOneWidget);
      expect(find.text('Start over'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Episode 4'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Watched'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Continue watching'), findsOneWidget);
      expect(find.text('Episode 4 of 30'), findsOneWidget);
    });
  }
}
