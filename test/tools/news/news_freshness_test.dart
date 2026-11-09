import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/news/config.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_db_helper.dart';
import 'package:tool_lab/tools/news/news_feed_parser.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = NewsDbHelper.instance;
  const source = NewsSource(
    shortId: 'freshness',
    title: 'Source',
    feedUrl: 'https://example.test/feed',
    createdAt: 1,
    updatedAt: 1,
  );

  NewsArticle article(String key, int publishedAt) => NewsArticle(
    guidKey: key,
    sourceShortId: source.shortId,
    title: key,
    link: 'https://example.test/$key',
    publishedAt: publishedAt,
    fetchedAt: DateTime.now().millisecondsSinceEpoch,
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
  });
  setUp(() async {
    await db.clearArticles();
    final toolDb = await DatabaseService.instance.getToolDatabase(
      NewsTool.config.id,
    );
    await toolDb.delete(NewsDbHelper.readBucketsTable);
    await toolDb.delete(NewsDbHelper.readMarksTable);
    await db.saveSource(source);
  });
  tearDownAll(() => DatabaseService.instance.close());

  test('old items stay cached but are not new or unread', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = NewsDbHelper.newArticleCutoff(now);
    final fresh = article(
      'fresh',
      now - const Duration(hours: 1).inMilliseconds,
    );
    final old = article('old', now - const Duration(days: 3).inMilliseconds);
    expect(await db.saveFetchedArticles(source.shortId, [fresh, old]), 1);

    final all = {
      for (final item in await db.getArticles(newSince: cutoff))
        item.guidKey: item,
    };
    expect(all['fresh']!.isRead, isFalse);
    expect(all['old']!.isRead, isTrue);
    expect(all['old']!.readAt, isNull);
    expect(
      (await db.getArticles(
        unreadOnly: true,
        newSince: cutoff,
      )).map((item) => item.guidKey),
      ['fresh'],
    );
    expect(await db.getUnreadCounts(newSince: cutoff), {source.shortId: 1});
    expect(
      await db.getNextUnreadExpiry(newSince: cutoff),
      fresh.publishedAt + NewsDbHelper.newArticleWindow.inMilliseconds + 1,
    );
    expect(
      (await db.getArticles(
        unreadOnly: true,
        newSince: fresh.publishedAt,
      )).map((item) => item.guidKey),
      ['fresh'],
    );
    expect(
      await db.getArticles(unreadOnly: true, newSince: fresh.publishedAt + 1),
      isEmpty,
    );

    await db.markAllRead();
    final after = {
      for (final item in await db.getArticles()) item.guidKey: item,
    };
    expect(after['fresh']!.readAt, isNotNull);
    expect(after['old']!.readAt, isNull);
    final reads = (await db.getReadBuckets(
      onlyPending: true,
    )).expand((bucket) => bucket.reads.keys);
    expect(reads, contains('fresh'));
    expect(reads, isNot(contains('old')));
  });

  test(
    'undated items keep first fetch time until a feed date is available',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      ParsedFeedItem item(int publishedAt) => ParsedFeedItem(
        guidKey: 'undated',
        title: 'Undated',
        summary: '',
        author: null,
        link: 'https://example.test/undated',
        imageUrl: null,
        publishedAt: publishedAt,
        contentHtml: '',
      );
      final firstFetch = now - const Duration(days: 3).inMilliseconds;
      expect(
        await db.saveFetchedArticles(source.shortId, [
          item(
            0,
          ).toArticle(sourceShortId: source.shortId, fetchedAt: firstFetch),
        ]),
        0,
      );
      await db.saveFetchedArticles(source.shortId, [
        item(0).toArticle(sourceShortId: source.shortId, fetchedAt: now),
      ]);
      expect((await db.getArticles()).single.publishedAt, firstFetch);
      expect((await db.getArticles()).single.isRead, isTrue);
      final feedDate = now - const Duration(days: 4).inMilliseconds;
      await db.saveFetchedArticles(source.shortId, [
        item(feedDate).toArticle(sourceShortId: source.shortId, fetchedAt: now),
      ]);
      expect((await db.getArticles()).single.publishedAt, feedDate);
    },
  );

  test(
    'opening an old article records a real read without changing unread count',
    () async {
      final settings = DatabaseService.instance;
      await settings.setSetting(NewsTool.config.id, 'seed_done', 'true');
      await settings.setSetting(NewsTool.config.id, 'refresh_on_open', 'false');
      final state = NewsState();
      addTearDown(state.dispose);
      await state.init();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.saveFetchedArticles(source.shortId, [
        article('fresh', now),
        article('old', now - const Duration(days: 3).inMilliseconds),
      ]);
      await state.reload();
      expect(state.totalUnread, 1);
      expect(await db.getReadBuckets(), isEmpty);
      final old = state.articles.singleWhere((item) => item.guidKey == 'old');
      await state.markRead(old);
      expect(state.totalUnread, 1);
      expect(
        state.articles.singleWhere((item) => item.guidKey == 'old').readAt,
        isNotNull,
      );
      expect(
        (await db.getReadBuckets(
          onlyPending: true,
        )).expand((bucket) => bucket.reads.keys),
        contains('old'),
      );
    },
  );

  test(
    'unread counts update when an article ages out while News is open',
    () async {
      final settings = DatabaseService.instance;
      await settings.setSetting(NewsTool.config.id, 'seed_done', 'true');
      await settings.setSetting(NewsTool.config.id, 'refresh_on_open', 'false');
      final state = NewsState();
      addTearDown(state.dispose);
      await state.init();
      final now = DateTime.now().millisecondsSinceEpoch;
      final soon = now - NewsDbHelper.newArticleWindow.inMilliseconds + 1500;
      await db.saveFetchedArticles(source.shortId, [article('expiring', soon)]);
      await state.reload();
      expect(state.totalUnread, 1);
      final expired = Completer<void>();
      state.addListener(() {
        if (state.totalUnread == 0 && !expired.isCompleted) expired.complete();
      });
      await expired.future.timeout(const Duration(seconds: 5));
      expect(state.articles.single.isRead, isTrue);
      expect(state.articles.single.readAt, isNull);
      expect(await db.getReadBuckets(), isEmpty);
    },
  );
}
