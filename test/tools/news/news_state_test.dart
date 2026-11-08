import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/news/config.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_catalog.dart';
import 'package:tool_lab/tools/news/news_db_helper.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
  });

  test(
    'read filtering waits for refresh and excludes disabled sources',
    () async {
      await DatabaseService.instance.setSetting(
        NewsTool.config.id,
        'refresh_on_open',
        'false',
      );
      final state = NewsState();
      addTearDown(state.dispose);
      await state.init();
      for (final title in [
        'The Verge',
        'Hacker News',
        'The Guardian Business',
        'heise online',
        'ScienceDaily',
        'Caschys Blog',
        'Managermagazin',
        'Danisch',
      ]) {
        final source = state.sources.singleWhere((s) => s.title == title);
        expect(source.enabled, isTrue);
        expect(NewsCatalog.categoryForFeed(source.feedUrl), isNotNull);
      }
      final alJazeera = state.sources.singleWhere(
        (s) => s.title == 'Al Jazeera',
      );
      expect(alJazeera.enabled, isFalse);
      final source = state.enabledSources.first;
      final now = DateTime.now().millisecondsSinceEpoch;
      NewsArticle article(String key, String sourceId) => NewsArticle(
        guidKey: key,
        sourceShortId: sourceId,
        title: key,
        link: 'https://example.invalid/$key',
        publishedAt: now,
        fetchedAt: now,
      );

      final db = NewsDbHelper.instance;
      await db.saveFetchedArticles(source.shortId, [
        article('first', source.shortId),
        article('second', source.shortId),
      ]);
      await db.saveFetchedArticles(alJazeera.shortId, [
        article('disabled', alJazeera.shortId),
      ]);
      await state.reload();
      expect(
        state.articles.map((a) => a.guidKey),
        containsAll(['first', 'second']),
      );
      expect(state.articles.map((a) => a.guidKey), isNot(contains('disabled')));
      expect(state.totalUnread, 2);

      await state.setHideRead(true);
      final first = state.articles.singleWhere((a) => a.guidKey == 'first');
      await state.markRead(first);
      expect(
        state.articles.singleWhere((a) => a.guidKey == 'first').isRead,
        isTrue,
      );
      expect(state.totalUnread, 1);
      await state.markRead(first);
      expect(state.totalUnread, 1);
      await state.reload();
      expect(
        state.articles.singleWhere((a) => a.guidKey == 'first').isRead,
        isTrue,
      );
      await state.setSelectedSource(source.shortId);
      expect(
        state.articles.singleWhere((a) => a.guidKey == 'first').isRead,
        isTrue,
      );
      await state.refresh(only: []);
      expect(state.articles.map((a) => a.guidKey), ['second']);
      await state.setHideRead(false);
      expect(
        state.articles.singleWhere((a) => a.guidKey == 'first').isRead,
        isTrue,
      );

      await state.setSourceEnabled(source, false);
      expect(state.selectedSourceId, isNull);
      expect(state.articles, isEmpty);
      expect(state.totalUnread, 0);
      await state.setSourceEnabled(source, true);
      expect(
        state.articles.map((a) => a.guidKey),
        containsAll(['first', 'second']),
      );
      expect(state.totalUnread, 1);
      await state.setSourceEnabled(alJazeera, true);
      expect(state.articles.map((a) => a.guidKey), contains('disabled'));
      expect(state.totalUnread, 2);

      final previewReady = Completer<void>();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.host, 'example.invalid');
        return http.Response(
          '<html><head><meta property="og:image" content="/photo.jpg"></head>'
          '<body><article><p>This article has enough content to be cached and '
          'displayed when the user opens it from the timeline.</p></article></body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      });
      AppHttpClient.testClient = client;
      addTearDown(() {
        AppHttpClient.testClient = null;
        client.close();
      });
      void onPreview() {
        if (state.articles.any(
              (a) => a.guidKey == 'first' && a.imageUrl != null,
            ) &&
            !previewReady.isCompleted) {
          previewReady.complete();
        }
      }

      state.addListener(onPreview);
      state.prefetchArticleImage(first);
      await previewReady.future.timeout(const Duration(seconds: 5));
      state.removeListener(onPreview);
      expect(requests, 1);
      expect(
        state.articles.singleWhere((a) => a.guidKey == 'first').imageUrl,
        'https://example.invalid/photo.jpg',
      );
      final cached = await state.loadArticleBody(first);
      expect(cached.markdown, contains('cached'));
      expect(requests, 1);
      await db.saveFetchedArticles(source.shortId, [
        article('first', source.shortId),
      ]);
      expect(
        (await db.getArticles())
            .singleWhere((a) => a.guidKey == 'first')
            .imageUrl,
        'https://example.invalid/photo.jpg',
      );
    },
  );

  test('discovers and caches videos for an older cached article', () async {
    final db = NewsDbHelper.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    final source = await db.saveSource(
      const NewsSource(
        shortId: 'video-source',
        title: 'Video source',
        feedUrl: 'https://example.invalid/feed',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
    final article = NewsArticle(
      guidKey: 'cached-video-item',
      sourceShortId: source.shortId,
      title: 'Video story',
      link: 'https://example.invalid/video-story',
      publishedAt: now,
      fetchedAt: now,
    );
    await db.saveFetchedArticles(source.shortId, [article]);
    await db.setArticleContent(article.guidKey, 'Old cached article');
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(
        '<article><p>A full article with enough text to be accepted by the '
        'reader.</p><video src="/video.mp4"></video></article>',
        200,
        headers: {'content-type': 'text/html'},
      );
    });
    AppHttpClient.testClient = client;
    addTearDown(() {
      AppHttpClient.testClient = null;
      client.close();
    });
    final state = NewsState();
    addTearDown(state.dispose);
    final extracted = await state.loadArticleBody(article);
    expect(extracted.videoUrls, ['https://example.invalid/video.mp4']);
    expect(
      (await state.loadArticleBody(article)).videoUrls,
      extracted.videoUrls,
    );
    expect(requests, 1);
  });

  test('keeps older cached article when video discovery fails', () async {
    final db = NewsDbHelper.instance;
    const article = NewsArticle(
      guidKey: 'offline-video-item',
      sourceShortId: 'offline-source',
      title: 'Offline story',
      link: 'https://example.invalid/offline',
      publishedAt: 1,
      fetchedAt: 1,
    );
    await db.saveFetchedArticles(article.sourceShortId, [article]);
    await db.setArticleContent(article.guidKey, 'Existing cached article');
    final client = MockClient((_) async => http.Response('', 503));
    AppHttpClient.testClient = client;
    addTearDown(() {
      AppHttpClient.testClient = null;
      client.close();
    });
    final state = NewsState();
    addTearDown(state.dispose);
    final extracted = await state.loadArticleBody(article);
    expect(extracted.markdown, 'Existing cached article');
    expect(extracted.videoUrls, isEmpty);
  });
}
