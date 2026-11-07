import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/news/news_article.dart';
import 'package:tool_lab/tools/news/news_db_helper.dart';
import 'package:tool_lab/tools/news/news_source.dart';
import 'package:tool_lab/tools/news/news_sync_delegate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = NewsDbHelper.instance;
  final now = DateTime.now().millisecondsSinceEpoch;

  NewsArticle article(String key) => NewsArticle(
    guidKey: key,
    sourceShortId: 'readtest',
    title: key,
    link: 'https://example.test/$key',
    publishedAt: now,
    fetchedAt: now,
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.instance.dbPathOverride = inMemoryDatabasePath;
    await db.saveSource(
      const NewsSource(
        shortId: 'readtest',
        title: 'Test',
        feedUrl: 'https://example.test/feed',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  });

  tearDownAll(() async {
    AppHttpClient.testClient = null;
    await DatabaseService.instance.close();
  });

  test('remote marks apply before or after fetching and expire', () async {
    await db.saveFetchedArticles('readtest', [article('already')]);
    final sync = NewsSyncDelegate();
    await sync.savePulledRecord(
      id: 'read:REMOTE:0',
      updatedAt: now,
      deleted: false,
      data: {
        'reads': {
          'already': now,
          'later': now,
          'expired': now - NewsDbHelper.readRetentionMs - 1,
        },
      },
    );
    await db.saveFetchedArticles('readtest', [
      article('later'),
      article('expired'),
    ]);
    final articles = {for (final a in await db.getArticles()) a.guidKey: a};
    expect(articles['already']!.isRead, isTrue);
    expect(articles['later']!.isRead, isTrue);
    expect(articles['expired']!.isRead, isFalse);
    await db.clearArticles();
    await db.saveFetchedArticles('readtest', [article('later')]);
    expect((await db.getArticles()).single.isRead, isTrue);
  });

  test(
    'rotating slots are bounded and sync finalization preserves newer writes',
    () async {
      for (var days = 10; days >= 0; days--) {
        final item = article('day$days');
        await db.saveFetchedArticles('readtest', [item]);
        final saved = (await db.getArticles()).singleWhere(
          (a) => a.guidKey == item.guidKey,
        );
        await db.markRead(
          saved.id!,
          readAt: now - days * const Duration(days: 1).inMilliseconds,
        );
      }
      final buckets = (await db.getReadBuckets())
          .where((b) => !b.id.contains('REMOTE'))
          .toList();
      expect(buckets.length, 8);
      expect(buckets.expand((b) => b.reads.keys), isNot(contains('day8')));
      final sync = NewsSyncDelegate();
      final metadata = await sync.getLocalSyncRecords();
      final id =
          metadata.firstWhere(
                (r) =>
                    r['id'].toString().startsWith('read:') &&
                    !r['id'].toString().contains('REMOTE'),
              )['id']
              as String;
      final prior = (await db.getReadBucket(id))!;
      final day = prior.reads.values.first;
      final item = article('race');
      await db.saveFetchedArticles('readtest', [item]);
      final saved = (await db.getArticles()).singleWhere(
        (a) => a.guidKey == 'race',
      );
      await db.markRead(saved.id!, readAt: day + 1);
      await sync.finalizeLocalSync(id, false);
      expect((await db.getReadBucket(id))!.synced, isFalse);
    },
  );

  test(
    'database restore creates a new writer and keeps pending reads',
    () async {
      final old = (await db.getReadBuckets(
        onlyPending: true,
      )).where((bucket) => !bucket.id.contains('REMOTE')).toList();
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - NewsDbHelper.readRetentionMs;
      final recent = old
          .expand((bucket) => bucket.reads.entries)
          .where((entry) => entry.value >= cutoff)
          .map((entry) => entry.key)
          .toSet();
      await db.resetAfterDatabaseRestore();
      final restored = await db.getReadBuckets(onlyPending: true);
      expect(
        restored
            .map((bucket) => bucket.id)
            .toSet()
            .intersection(old.map((bucket) => bucket.id).toSet()),
        isEmpty,
      );
      expect(
        restored.expand((bucket) => bucket.reads.keys).toSet(),
        containsAll(recent),
      );
    },
  );

  test('a pulled source does not overwrite a newer local edit', () async {
    final original = (await db.getSource('readtest'))!;
    final local = await db.saveSource(
      original.copyWith(title: 'New local title'),
    );
    await db.savePulledSource(
      original.copyWith(
        title: 'Older remote title',
        updatedAt: local.updatedAt - 1,
      ),
      deleted: false,
    );
    expect((await db.getSource('readtest'))!.title, 'New local title');
  });

  test('sync sends hashes and uses the server revision cursor', () async {
    final server = <String, Map<String, dynamic>>{};
    final revisions = <String, int>{};
    var revision = 0;
    server['read:OTHER:1'] = {
      'id': 'read:OTHER:1',
      'updatedAt': now,
      'deleted': false,
      'data': {
        'reads': {'network-later': now},
      },
    };
    revisions['read:OTHER:1'] = ++revision;
    final seenCursors = <String?>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/metadata')) {
        final cursor = request.url.queryParameters['cursor'];
        seenCursors.add(cursor);
        final after = int.tryParse(cursor ?? '') ?? 0;
        return http.Response(
          jsonEncode({
            'success': true,
            'full': cursor == null,
            'cursor': '$revision',
            'records': [
              for (final entry in server.entries)
                if (cursor == null || revisions[entry.key]! > after)
                  {
                    'id': entry.key,
                    'updatedAt': entry.value['updatedAt'],
                    'deleted': false,
                  },
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/pull')) {
        final ids = (jsonDecode(request.body) as Map)['ids'] as List;
        return http.Response(
          jsonEncode({
            'success': true,
            'records': [for (final id in ids) server[id]],
          }),
          200,
        );
      }
      final records = (jsonDecode(request.body) as Map)['records'] as List;
      for (final record in records.cast<Map<String, dynamic>>()) {
        server[record['id'] as String] = record;
        revisions[record['id'] as String] = ++revision;
      }
      return http.Response(jsonEncode({'success': true}), 200);
    });
    AppHttpClient.testClient = client;
    addTearDown(() {
      AppHttpClient.testClient = null;
      client.close();
    });
    await SyncService.sync(
      baseUrl: 'https://sync.test',
      userId: 'test',
      delegate: NewsSyncDelegate(),
      backendAlreadyChecked: true,
    );
    await db.saveFetchedArticles('readtest', [article('network-later')]);
    expect(
      (await db.getArticles())
          .singleWhere((a) => a.guidKey == 'network-later')
          .isRead,
      isTrue,
    );
    final readRecords = server.values
        .where((r) => (r['id'] as String).startsWith('read:'))
        .toList();
    expect(readRecords, isNotEmpty);
    expect(jsonEncode(readRecords), isNot(contains('https://example.test')));
    await db.saveFetchedArticles('readtest', [article('local-delta')]);
    final delta = (await db.getArticles()).singleWhere(
      (a) => a.guidKey == 'local-delta',
    );
    await db.markRead(delta.id!);
    server['read:OTHER:2'] = {
      'id': 'read:OTHER:2',
      'updatedAt': now + 1,
      'deleted': false,
      'data': {
        'reads': {'remote-delta': now},
      },
    };
    revisions['read:OTHER:2'] = ++revision;
    await SyncService.sync(
      baseUrl: 'https://sync.test',
      userId: 'test',
      delegate: NewsSyncDelegate(),
      backendAlreadyChecked: true,
    );
    expect(seenCursors.first, isNull);
    expect(seenCursors.last, isNotNull);
    expect(jsonEncode(server.values.toList()), contains('local-delta'));
    await db.saveFetchedArticles('readtest', [article('remote-delta')]);
    expect(
      (await db.getArticles())
          .singleWhere((a) => a.guidKey == 'remote-delta')
          .isRead,
      isTrue,
    );
  });
}
