import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_db_helper.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_sync_delegate.dart';

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

  test('preserves read state and invalidates stale feed validators', () async {
    final db = NewsDbHelper.instance;
    const source = NewsSource(
      shortId: 'source',
      title: 'Source',
      feedUrl: 'https://example.com/feed',
      createdAt: 1,
      updatedAt: 1,
    );
    await db.saveSource(source);
    await db.updateFetchState(
      source.shortId,
      etag: 'etag',
      lastModified: 'date',
    );

    const article = NewsArticle(
      guidKey: 'item',
      sourceShortId: 'source',
      title: 'Original',
      link: 'https://example.com/item',
      publishedAt: 10,
      fetchedAt: 10,
    );
    expect(await db.saveFetchedArticles(source.shortId, [article]), 1);
    final first = (await db.getArticles()).single;
    await db.markRead(first.id!);
    await db.setArticleContent(article.guidKey, 'Cached article');
    expect(
      await db.saveFetchedArticles(source.shortId, [
        article.copyWith(title: 'Updated'),
      ]),
      0,
    );
    expect((await db.getArticles()).single.isRead, isTrue);
    expect(await db.getArticleContent(article.guidKey), 'Cached article');

    final changed = await db.saveSource(
      source.copyWith(feedUrl: 'https://example.com/other'),
    );
    expect(changed.etag, isNull);
    expect(changed.lastModified, isNull);
    await db.updateFetchState(
      source.shortId,
      etag: 'new',
      lastModified: 'new-date',
    );
    await db.clearArticles();
    expect(await db.getArticles(), isEmpty);
    final cleared = (await db.getSource(source.shortId))!;
    expect(cleared.etag, isNull);
    expect(cleared.lastModified, isNull);

    await db.updateFetchState(
      source.shortId,
      etag: 'new',
      lastModified: 'new-date',
    );
    await db.savePulledSource(
      changed.copyWith(feedUrl: 'https://example.com/synced'),
      deleted: false,
    );
    final pulled = (await db.getSource(source.shortId))!;
    expect(pulled.etag, isNull);
    expect(pulled.lastModified, isNull);
    final sync = NewsSyncDelegate();
    expect((await sync.getLocalSyncRecords()).single['id'], source.shortId);
    expect(
      (await sync.getLocalRecordData(source.shortId))!['feedUrl'],
      pulled.feedUrl,
    );
    await db.deleteSource(source.shortId);
    expect((await sync.getLocalSyncRecords()).single['deleted'], isTrue);
    expect(await sync.getLocalRecordData(source.shortId), isNull);
  });
}
