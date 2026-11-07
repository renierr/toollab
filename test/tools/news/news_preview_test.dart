import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/news/config.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_db_helper.dart';
import 'package:tool_lab/tools/news/news_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  tearDownAll(() async => DatabaseService.instance.close());

  test(
    'preview requests are bounded and share fetches with the reader',
    () async {
      await DatabaseService.instance.setSetting(
        NewsTool.config.id,
        'refresh_on_open',
        'false',
      );
      final state = NewsState();
      addTearDown(state.dispose);
      await state.init();
      final source = state.enabledSources.first;
      final now = DateTime.now().millisecondsSinceEpoch;
      await NewsDbHelper.instance.saveFetchedArticles(source.shortId, [
        for (var i = 0; i < 3; i++)
          NewsArticle(
            guidKey: '$i',
            sourceShortId: source.shortId,
            title: 'Title $i',
            link: 'https://example.invalid/$i',
            publishedAt: now,
            fetchedAt: now,
          ),
      ]);
      await state.reload();
      final startedTwo = Completer<void>();
      final startedThree = Completer<void>();
      final responses = <String, Completer<http.Response>>{};
      var active = 0;
      var maxActive = 0;
      final client = MockClient((request) async {
        active++;
        if (active > maxActive) maxActive = active;
        final response = responses.putIfAbsent(
          request.url.path,
          Completer<http.Response>.new,
        );
        if (responses.length == 2 && !startedTwo.isCompleted) {
          startedTwo.complete();
        }
        if (responses.length == 3 && !startedThree.isCompleted) {
          startedThree.complete();
        }
        try {
          return await response.future;
        } finally {
          active--;
        }
      });
      AppHttpClient.testClient = client;
      addTearDown(() {
        AppHttpClient.testClient = null;
        client.close();
      });
      for (final article in state.articles) {
        state.prefetchArticleImage(article);
      }
      await startedTwo.future.timeout(const Duration(seconds: 5));
      expect(responses, hasLength(2));

      final firstPath = responses.keys.first;
      final first = state.articles.singleWhere(
        (a) => Uri.parse(a.link).path == firstPath,
      );
      final reader = state.loadArticleBody(first);
      final html =
          '<html><head><meta property="og:image" content="/hero.jpg"></head>'
          '<body><article><p>This article has enough content to be cached and '
          'displayed when the user opens it from the timeline.</p></article></body></html>';
      http.Response response() =>
          http.Response(html, 200, headers: {'content-type': 'text/html'});
      responses[firstPath]!.complete(response());
      expect((await reader).markdown, contains('cached'));
      await startedThree.future.timeout(const Duration(seconds: 5));
      expect(maxActive, 2);
      final allImages = Completer<void>();
      void onImages() {
        if (state.articles.every((a) => a.imageUrl != null) &&
            !allImages.isCompleted) {
          allImages.complete();
        }
      }

      state.addListener(onImages);
      for (final pending in responses.values.where((c) => !c.isCompleted)) {
        pending.complete(response());
      }
      await allImages.future.timeout(const Duration(seconds: 5));
      state.removeListener(onImages);
    },
  );
}
