import 'dart:convert';
import 'dart:math';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/id_helper.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'news_article.dart';
import 'news_catalog.dart';
import 'news_read_bucket.dart';
import 'news_source.dart';

part 'news_read_marks.dart';

class NewsDbHelper {
  static const String sourcesTable = 'sources';
  static const String articlesTable = 'articles';
  static const String readMarksTable = 'read_marks';
  static const String readBucketsTable = 'read_buckets';
  static const int _dayMs = 86400000;
  static const int _bucketCount = 8;
  static const int readRetentionMs = 7 * _dayMs;
  static const Duration newArticleWindow = Duration(days: 2);
  static const String readBucketPrefix = 'read:';

  /// Setting-key prefix shared with `AppState`, which clears cursors by it.
  static const String syncCursorPrefix = 'sync_cursor_';
  static const String _writerIdKey = 'read_writer_id';
  static const int _chunkSize = 400;

  /// Read articles are disposable once they are old; unread ones are kept long
  /// enough that a reader coming back after a break still finds a timeline.
  static const Duration _readRetention = Duration(days: 30);
  static const Duration _unreadRetention = Duration(days: 365);
  static const int _maxArticles = 5000;

  NewsDbHelper._privateConstructor();
  static final NewsDbHelper instance = NewsDbHelper._privateConstructor();

  static int newArticleCutoff([int? now]) =>
      (now ?? DateTime.now().millisecondsSinceEpoch) -
      newArticleWindow.inMilliseconds;

  Future<ToolDatabase>? _dbFuture;
  Future<String>? _writerFuture;

  Future<ToolDatabase> _getDb() => _dbFuture ??= _openDb();

  Future<ToolDatabase> _openDb() async {
    final db = await DatabaseService.instance.getToolDatabase(
      NewsTool.config.id,
    );
    try {
      await db.migrate(
        currentVersion: 3,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(sourcesTable)} (
                short_id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                feed_url TEXT NOT NULL,
                site_url TEXT NOT NULL DEFAULT '',
                category TEXT NOT NULL DEFAULT '',
                enabled INTEGER NOT NULL DEFAULT 1,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0,
                synced INTEGER NOT NULL DEFAULT 0,
                etag TEXT,
                last_modified TEXT,
                last_fetched_at INTEGER NOT NULL DEFAULT 0,
                last_error TEXT
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(articlesTable)} (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                guid_key TEXT NOT NULL UNIQUE,
                source_short_id TEXT NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL DEFAULT '',
                author TEXT,
                link TEXT NOT NULL,
                image_url TEXT,
                published_at INTEGER NOT NULL,
                content_md TEXT,
                read_at INTEGER,
                fetched_at INTEGER NOT NULL
              )
            ''');
            await txn.execute(
              'CREATE INDEX ${txn.nameTable('articles_timeline')} '
              'ON ${txn.nameTable(articlesTable)} (published_at DESC)',
            );
            await txn.execute(
              'CREATE INDEX ${txn.nameTable('articles_source')} '
              'ON ${txn.nameTable(articlesTable)} (source_short_id)',
            );
            await txn.execute(
              'CREATE INDEX ${txn.nameTable('sources_feed')} '
              'ON ${txn.nameTable(sourcesTable)} (feed_url)',
            );
          }
          if (oldVersion < 2) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(readMarksTable)} (
                guid_key TEXT PRIMARY KEY,
                read_at INTEGER NOT NULL
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(readBucketsTable)} (
                id TEXT PRIMARY KEY,
                updated_at INTEGER NOT NULL,
                synced INTEGER NOT NULL DEFAULT 0,
                reads TEXT NOT NULL
              )
            ''');
          }
          if (oldVersion < 3) {
            await txn.execute(
              'ALTER TABLE ${txn.nameTable(articlesTable)} ADD COLUMN video_urls TEXT',
            );
          }
        },
      );
    } catch (e) {
      _dbFuture = null;
      errorLog('[NewsDbHelper] Migration failed: $e');
      rethrow;
    }
    return db;
  }

  static String _randomId([int length = 10]) =>
      randomId(length, alphabet: unambiguousAlphanumeric);

  static String _enabledSourcesQuery(ToolDatabaseExecutor db) =>
      'SELECT short_id FROM ${db.nameTable(sourcesTable)} '
      'WHERE enabled = 1 AND deleted = 0';

  Future<List<NewsSource>> getSources() async {
    final db = await _getDb();
    final rows = await db.query(
      sourcesTable,
      where: 'deleted = 0',
      orderBy: 'sort_order ASC, title COLLATE NOCASE ASC',
    );
    return rows.map(NewsSource.fromMap).toList();
  }

  /// Includes deleted sources that still wait to sync their tombstone.
  Future<NewsSource?> getSource(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      sourcesTable,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : NewsSource.fromMap(rows.first);
  }

  Future<NewsSource?> getSourceByFeedUrl(String feedUrl) async {
    final db = await _getDb();
    final rows = await db.query(
      sourcesTable,
      where: 'feed_url = ? AND deleted = 0',
      whereArgs: [feedUrl],
      limit: 1,
    );
    return rows.isEmpty ? null : NewsSource.fromMap(rows.first);
  }

  /// The id a new source for [feedUrl] should get. Ids are hashed from the
  /// URL, but an edited source keeps its old id, so the hash may be taken.
  Future<String> availableShortId(String feedUrl) async {
    final id = NewsCatalog.shortIdForFeed(feedUrl);
    final existing = await getSource(id);
    if (existing == null || existing.feedUrl == feedUrl.trim()) return id;
    return 'N${_randomId()}';
  }

  Future<int> getNextSortOrder() async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT MAX(sort_order) AS max_order FROM ${db.nameTable(sourcesTable)}',
    );
    return (rows.first['max_order'] as int? ?? 0) + 1;
  }

  Future<NewsSource> saveSource(NewsSource source) async {
    final db = await _getDb();
    final existing = await getSource(source.shortId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final saved = source.copyWith(
      createdAt: source.createdAt == 0
          ? now
          : (existing?.createdAt ?? source.createdAt),
      updatedAt: max(now, (existing?.updatedAt ?? 0) + 1),
      synced: false,
    );
    if (existing == null) {
      await db.insert(sourcesTable, saved.toMap());
    } else {
      final feedChanged = existing.feedUrl != source.feedUrl;
      await db.update(
        sourcesTable,
        saved
            .copyWith(
              etag: existing.etag,
              lastModified: existing.lastModified,
              lastFetchedAt: existing.lastFetchedAt,
              lastError: existing.lastError,
              clearEtag: feedChanged,
              clearError: feedChanged,
            )
            .toMap(),
        where: 'short_id = ?',
        whereArgs: [source.shortId],
      );
    }
    return (await getSource(source.shortId))!;
  }

  Future<void> updateFetchState(
    String shortId, {
    String? etag,
    String? lastModified,
    String? error,
    bool keepValidators = false,
  }) async {
    final db = await _getDb();
    await db.update(
      sourcesTable,
      {
        if (!keepValidators) 'etag': etag,
        if (!keepValidators) 'last_modified': lastModified,
        'last_fetched_at': DateTime.now().millisecondsSinceEpoch,
        'last_error': error,
      },
      where: 'short_id = ?',
      whereArgs: [shortId],
    );
  }

  Future<void> deleteSource(String shortId) async {
    final db = await _getDb();
    final existing = await getSource(shortId);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        sourcesTable,
        {
          'deleted': 1,
          'synced': 0,
          'updated_at': max(now, (existing?.updatedAt ?? 0) + 1),
        },
        where: 'short_id = ?',
        whereArgs: [shortId],
      );
      await txn.delete(
        articlesTable,
        where: 'source_short_id = ?',
        whereArgs: [shortId],
      );
    });
  }

  Future<void> hardDeleteSource(String shortId, {int? updatedAt}) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      final removed = await txn.delete(
        sourcesTable,
        where: updatedAt == null
            ? 'short_id = ?'
            : 'short_id = ? AND updated_at = ?',
        whereArgs: updatedAt == null ? [shortId] : [shortId, updatedAt],
      );
      if (removed != 0) {
        await txn.delete(
          articlesTable,
          where: 'source_short_id = ?',
          whereArgs: [shortId],
        );
      }
    });
  }

  Future<void> markSourceSynced(String shortId, {int? updatedAt}) async {
    final db = await _getDb();
    await db.update(
      sourcesTable,
      {'synced': 1},
      where: updatedAt == null
          ? 'short_id = ?'
          : 'short_id = ? AND updated_at = ?',
      whereArgs: updatedAt == null ? [shortId] : [shortId, updatedAt],
    );
  }

  Future<List<NewsArticle>> getArticles({
    String? sourceShortId,
    bool unreadOnly = false,
    int? readAfter,
    int? newSince,
    int limit = 2000,
  }) async {
    final db = await _getDb();
    final cutoff = newSince ?? newArticleCutoff();
    final conditions = ['source_short_id IN (${_enabledSourcesQuery(db)})'];
    final args = <Object?>[];
    if (sourceShortId != null) {
      conditions.add('source_short_id = ?');
      args.add(sourceShortId);
    }
    if (unreadOnly) {
      conditions.add('published_at >= ?');
      args.add(cutoff);
      if (readAfter == null) {
        conditions.add('read_at IS NULL');
      } else {
        conditions.add('(read_at IS NULL OR read_at > ?)');
        args.add(readAfter);
      }
    }
    final rows = await db.query(
      articlesTable,
      columns: [
        'id',
        'guid_key',
        'source_short_id',
        'title',
        'summary',
        'author',
        'link',
        'image_url',
        'published_at',
        'read_at',
        'fetched_at',
      ],
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'published_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((row) {
      final article = NewsArticle.fromMap(row);
      return article.copyWith(agedOut: article.publishedAt < cutoff);
    }).toList();
  }

  Future<Map<String, int>> getUnreadCounts({int? newSince}) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT source_short_id, COUNT(*) AS total '
      'FROM ${db.nameTable(articlesTable)} '
      'WHERE read_at IS NULL AND published_at >= ? AND source_short_id IN '
      '(${_enabledSourcesQuery(db)}) GROUP BY source_short_id',
      [newSince ?? newArticleCutoff()],
    );
    return {
      for (final row in rows)
        row['source_short_id'] as String: row['total'] as int? ?? 0,
    };
  }

  Future<int?> getNextUnreadExpiry({int? newSince}) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT MIN(published_at) AS oldest FROM ${db.nameTable(articlesTable)} '
      'WHERE read_at IS NULL AND published_at >= ? AND source_short_id IN '
      '(${_enabledSourcesQuery(db)})',
      [newSince ?? newArticleCutoff()],
    );
    final oldest = rows.first['oldest'] as int?;
    return oldest == null ? null : oldest + newArticleWindow.inMilliseconds + 1;
  }

  /// Inserts new feed entries and refreshes the card metadata of known ones
  /// without overwriting the read state or cached article body.
  Future<int> saveFetchedArticles(
    String sourceShortId,
    List<NewsArticle> articles,
  ) async {
    if (articles.isEmpty) return 0;
    final db = await _getDb();
    final newCutoff = newArticleCutoff();
    var added = 0;
    await db.transaction((txn) async {
      final existing = <String>{};
      final marks = <String, int>{};
      final cutoff = DateTime.now().millisecondsSinceEpoch - readRetentionMs;
      final keys = articles.map((a) => a.guidKey).toList();
      for (var start = 0; start < keys.length; start += _chunkSize) {
        final chunk = keys.sublist(start, min(start + _chunkSize, keys.length));
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await txn.query(
          articlesTable,
          columns: ['guid_key'],
          where: 'guid_key IN ($placeholders)',
          whereArgs: chunk,
        );
        existing.addAll(rows.map((r) => r['guid_key'] as String));
        final readRows = await txn.query(
          readMarksTable,
          columns: ['guid_key', 'read_at'],
          where: 'guid_key IN ($placeholders) AND read_at >= ?',
          whereArgs: [...chunk, cutoff],
        );
        for (final row in readRows) {
          marks[row['guid_key'] as String] = row['read_at'] as int;
        }
      }

      // One round trip for the whole feed instead of one per entry.
      final batch = txn.batch();
      for (final article in articles) {
        if (existing.contains(article.guidKey)) {
          batch.update(
            articlesTable,
            {
              'title': article.title,
              'summary': article.summary,
              'author': article.author,
              'link': article.link,
              if (article.hasPublicationDate && article.publishedAt > 0)
                'published_at': article.publishedAt,
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                'image_url': article.imageUrl,
              'fetched_at': article.fetchedAt,
            },
            where: 'guid_key = ?',
            whereArgs: [article.guidKey],
          );
        } else {
          batch.insert(
            articlesTable,
            article
                .copyWith(
                  sourceShortId: sourceShortId,
                  readAt: marks[article.guidKey],
                )
                .toMap(),
          );
          if (article.publishedAt >= newCutoff) added++;
        }
      }
      await batch.commit(noResult: true);
    });
    return added;
  }

  Future<NewsCachedContent?> getCachedContent(String guidKey) async {
    final db = await _getDb();
    final rows = await db.query(
      articlesTable,
      columns: ['content_md', 'video_urls'],
      where: 'guid_key = ?',
      whereArgs: [guidKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final videos = rows.first['video_urls'] as String?;
    return NewsCachedContent(
      markdown: rows.first['content_md'] as String?,
      videoUrls: videos == null
          ? null
          : (jsonDecode(videos) as List).whereType<String>().toList(),
    );
  }

  Future<void> setArticleContent(
    String guidKey,
    String markdown, {
    String? imageUrl,
    List<String>? videoUrls,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      if (markdown.isNotEmpty || (videoUrls?.isNotEmpty ?? false)) {
        await txn.update(
          articlesTable,
          {
            'content_md': markdown,
            if (videoUrls != null) 'video_urls': jsonEncode(videoUrls),
          },
          where: 'guid_key = ?',
          whereArgs: [guidKey],
        );
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await txn.update(
          articlesTable,
          {'image_url': imageUrl},
          where: "guid_key = ? AND (image_url IS NULL OR image_url = '')",
          whereArgs: [guidKey],
        );
      }
    });
  }

  Future<void> markRead(int id, {int? readAt}) async {
    final db = await _getDb();
    final writer = await _readWriterId();
    final time = readAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        articlesTable,
        columns: ['guid_key'],
        where: 'id = ? AND read_at IS NULL',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      await txn.update(
        articlesTable,
        {'read_at': time},
        where: 'id = ? AND read_at IS NULL',
        whereArgs: [id],
      );
      await _addReads(txn, writer, [rows.first['guid_key'] as String], time);
    });
  }

  Future<void> markAllRead({String? sourceShortId, int? readAt}) async {
    final db = await _getDb();
    final writer = await _readWriterId();
    final time = readAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final where =
          'read_at IS NULL AND published_at >= ? '
          'AND source_short_id IN (${_enabledSourcesQuery(txn)})'
          '${sourceShortId == null ? '' : ' AND source_short_id = ?'}';
      final args = [newArticleCutoff(), ?sourceShortId];
      final rows = await txn.query(
        articlesTable,
        columns: ['guid_key'],
        where: where,
        whereArgs: args,
      );
      if (rows.isEmpty) return;
      await txn.update(
        articlesTable,
        {'read_at': time},
        where: where,
        whereArgs: args,
      );
      await _addReads(
        txn,
        writer,
        rows.map((row) => row['guid_key'] as String),
        time,
      );
    });
  }

  Future<void> clearArticles() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(articlesTable);
      await txn.update(sourcesTable, {'etag': null, 'last_modified': null});
    });
  }

  Future<void> prune() async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete(
      articlesTable,
      where: 'read_at IS NOT NULL AND published_at < ?',
      whereArgs: [now - _readRetention.inMilliseconds],
    );
    await db.delete(
      articlesTable,
      where: 'published_at < ?',
      whereArgs: [now - _unreadRetention.inMilliseconds],
    );
    final table = db.nameTable(articlesTable);
    await db.rawDelete(
      'DELETE FROM $table WHERE id IN (SELECT id FROM $table '
      'ORDER BY published_at DESC LIMIT -1 OFFSET ?)',
      [_maxArticles],
    );
  }

  Future<List<NewsSource>> getSyncRecords() async {
    final db = await _getDb();
    final rows = await db.query(sourcesTable);
    return rows.map(NewsSource.fromMap).toList();
  }

  Future<void> savePulledSource(
    NewsSource source, {
    required bool deleted,
  }) async {
    final db = await _getDb();
    final existing = await getSource(source.shortId);
    if (deleted) {
      // A newer local edit wins and is pushed back on the next sync.
      if (existing != null && existing.updatedAt > source.updatedAt) return;
      await hardDeleteSource(source.shortId);
      return;
    }
    if (existing != null && existing.updatedAt >= source.updatedAt) return;
    if (existing == null) {
      await db.insert(
        sourcesTable,
        source.copyWith(synced: true, deleted: false).toMap(),
      );
    } else {
      await db.update(
        sourcesTable,
        {
          'title': source.title,
          'feed_url': source.feedUrl,
          'site_url': source.siteUrl,
          'category': source.category,
          'enabled': source.enabled ? 1 : 0,
          'sort_order': source.sortOrder,
          'created_at': source.createdAt,
          'updated_at': source.updatedAt,
          'deleted': 0,
          'synced': 1,
          if (existing.feedUrl != source.feedUrl) 'etag': null,
          if (existing.feedUrl != source.feedUrl) 'last_modified': null,
          if (existing.feedUrl != source.feedUrl) 'last_error': null,
        },
        where: 'short_id = ?',
        whereArgs: [source.shortId],
      );
    }
  }
}
