import 'dart:convert';
import 'dart:math';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'news_article.dart';
import 'news_read_bucket.dart';
import 'news_source.dart';

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

  Future<ToolDatabase> _getDb() => _dbFuture ??= _openDb();

  Future<ToolDatabase> _openDb() async {
    final db = await DatabaseService.instance.getToolDatabase(
      NewsTool.config.id,
    );
    try {
      await db.migrate(
        currentVersion: 2,
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
        },
      );
    } catch (e) {
      _dbFuture = null;
      errorLog('[NewsDbHelper] Migration failed: $e');
      rethrow;
    }
    return db;
  }

  String generateShortId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(10, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<List<NewsSource>> getSources() async {
    final db = await _getDb();
    final rows = await db.query(
      sourcesTable,
      where: 'deleted = 0',
      orderBy: 'sort_order ASC, title COLLATE NOCASE ASC',
    );
    return rows.map(NewsSource.fromMap).toList();
  }

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
    final conditions = <String>[
      'source_short_id IN (SELECT short_id FROM ${db.nameTable(sourcesTable)} '
          'WHERE enabled = 1 AND deleted = 0)',
    ];
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
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
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
      '(SELECT short_id FROM ${db.nameTable(sourcesTable)} '
      'WHERE enabled = 1 AND deleted = 0) GROUP BY source_short_id',
      [newSince ?? newArticleCutoff()],
    );
    return {
      for (final row in rows)
        row['source_short_id'] as String: row['total'] as int? ?? 0,
    };
  }

  Future<int> getTotalUnreadCount({int? newSince}) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${db.nameTable(articlesTable)} '
      'WHERE read_at IS NULL AND published_at >= ? AND source_short_id IN '
      '(SELECT short_id FROM ${db.nameTable(sourcesTable)} '
      'WHERE enabled = 1 AND deleted = 0)',
      [newSince ?? newArticleCutoff()],
    );
    return rows.first['total'] as int? ?? 0;
  }

  Future<int?> getNextUnreadExpiry({int? newSince}) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT MIN(published_at) AS oldest FROM ${db.nameTable(articlesTable)} '
      'WHERE read_at IS NULL AND published_at >= ? AND source_short_id IN '
      '(SELECT short_id FROM ${db.nameTable(sourcesTable)} '
      'WHERE enabled = 1 AND deleted = 0)',
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
      for (var start = 0; start < keys.length; start += 400) {
        final chunk = keys.sublist(start, min(start + 400, keys.length));
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

      for (final article in articles) {
        if (existing.contains(article.guidKey)) {
          await txn.update(
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
          await txn.insert(
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
    });
    return added;
  }

  Future<String?> getArticleContent(String guidKey) async {
    final db = await _getDb();
    final rows = await db.query(
      articlesTable,
      columns: ['content_md'],
      where: 'guid_key = ?',
      whereArgs: [guidKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['content_md'] as String?;
  }

  Future<void> setArticleContent(
    String guidKey,
    String markdown, {
    String? imageUrl,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      if (markdown.isNotEmpty) {
        await txn.update(
          articlesTable,
          {'content_md': markdown},
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

  Future<void> markReadByGuid(String guidKey) async {
    final db = await _getDb();
    final rows = await db.query(
      articlesTable,
      columns: ['id'],
      where: 'guid_key = ? AND read_at IS NULL',
      whereArgs: [guidKey],
      limit: 1,
    );
    if (rows.isNotEmpty) await markRead(rows.first['id'] as int);
  }

  Future<void> markAllRead({String? sourceShortId, int? readAt}) async {
    final db = await _getDb();
    final writer = await _readWriterId();
    final time = readAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final where = sourceShortId == null
          ? 'read_at IS NULL AND published_at >= ?'
          : 'read_at IS NULL AND published_at >= ? AND source_short_id = ?';
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

  Future<void> deleteArticle(int id) async {
    final db = await _getDb();
    await db.delete(articlesTable, where: 'id = ?', whereArgs: [id]);
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
    final overflow = await db.rawQuery(
      'SELECT id FROM ${db.nameTable(articlesTable)} '
      'ORDER BY published_at DESC LIMIT -1 OFFSET $_maxArticles',
    );
    if (overflow.isEmpty) return;
    final ids = overflow.map((row) => row['id'] as int).toList();
    await db.delete(
      articlesTable,
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<String>? _writerFuture;

  Future<String> _readWriterId() => _writerFuture ??= () async {
    final db = await _getDb();
    final id = '${generateShortId()}${generateShortId()}';
    return db.transaction((txn) async {
      await txn.executor.rawInsert(
        'INSERT OR IGNORE INTO tool_settings (tool_id, key, value, updated_at) VALUES (?, ?, ?, ?)',
        [
          NewsTool.config.id,
          'read_writer_id',
          id,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      final rows = await txn.executor.query(
        'tool_settings',
        columns: ['value'],
        where: 'tool_id = ? AND key = ?',
        whereArgs: [NewsTool.config.id, 'read_writer_id'],
      );
      return rows.single['value'] as String;
    });
  }();

  Future<void> _addReads(
    ToolDatabaseExecutor txn,
    String writer,
    Iterable<String> keys,
    int readAt,
  ) => _addReadEntries(txn, writer, {for (final key in keys) key: readAt});

  Future<void> _addReadEntries(
    ToolDatabaseExecutor txn,
    String writer,
    Map<String, int> entries,
  ) async {
    if (entries.isEmpty) return;
    final day = entries.values.first ~/ _dayMs;
    final id = '$readBucketPrefix$writer:${day % _bucketCount}';
    final rows = await txn.query(
      readBucketsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final old = rows.isEmpty ? null : NewsReadBucket.fromMap(rows.first);
    final reads = <String, int>{
      if (old != null)
        for (final entry in old.reads.entries)
          if (entry.value ~/ _dayMs == day) entry.key: entry.value,
    };
    for (final entry in entries.entries) {
      reads[entry.key] = entry.value;
      await txn.rawInsert(
        'INSERT INTO ${txn.nameTable(readMarksTable)} (guid_key, read_at) VALUES (?, ?) '
        'ON CONFLICT(guid_key) DO UPDATE SET read_at = MAX(read_at, excluded.read_at)',
        [entry.key, entry.value],
      );
    }
    await txn.rawInsert(
      'INSERT INTO ${txn.nameTable(readBucketsTable)} (id, updated_at, synced, reads) VALUES (?, ?, 0, ?) '
      'ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at, synced = 0, reads = excluded.reads',
      [
        id,
        max(DateTime.now().millisecondsSinceEpoch, (old?.updatedAt ?? 0) + 1),
        jsonEncode(reads),
      ],
    );
  }

  Future<void> prepareReadSync() async {
    final db = await _getDb();
    final writer = await _readWriterId();
    final cutoff = DateTime.now().millisecondsSinceEpoch - readRetentionMs;
    await db.transaction((txn) async {
      await txn.delete(
        readMarksTable,
        where: 'read_at < ?',
        whereArgs: [cutoff],
      );
      await txn.delete(
        readBucketsTable,
        where: 'updated_at < ?',
        whereArgs: [cutoff],
      );
      final rows = await txn.rawQuery(
        'SELECT a.guid_key, a.read_at FROM ${txn.nameTable(articlesTable)} a '
        'LEFT JOIN ${txn.nameTable(readMarksTable)} r ON r.guid_key = a.guid_key '
        'WHERE a.read_at >= ? AND r.guid_key IS NULL',
        [cutoff],
      );
      final grouped = <int, Map<String, int>>{};
      for (final row in rows) {
        final time = row['read_at'] as int;
        grouped.putIfAbsent(
          time ~/ _dayMs,
          () => {},
        )[row['guid_key'] as String] = time;
      }
      for (final entry in grouped.entries) {
        await _addReadEntries(txn, writer, entry.value);
      }
    });
  }

  Future<List<NewsReadBucket>> getReadBuckets({
    bool onlyPending = false,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      readBucketsTable,
      where: onlyPending ? 'synced = 0 AND updated_at >= ?' : 'updated_at >= ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch - readRetentionMs],
    );
    return rows.map(NewsReadBucket.fromMap).toList();
  }

  Future<List<NewsReadBucketMeta>> getReadBucketMetadata({
    bool onlyPending = false,
    List<String>? ids,
  }) async {
    final db = await _getDb();
    if (ids != null && ids.isEmpty) return [];
    final cutoff = DateTime.now().millisecondsSinceEpoch - readRetentionMs;
    final result = <NewsReadBucketMeta>[];
    final chunks = ids == null
        ? <List<String>?>[null]
        : <List<String>?>[
            for (var start = 0; start < ids.length; start += 400)
              ids.sublist(start, min(start + 400, ids.length)),
          ];
    for (final chunk in chunks) {
      final rows = await db.query(
        readBucketsTable,
        columns: ['id', 'updated_at'],
        where:
            'updated_at >= ?${onlyPending ? ' AND synced = 0' : ''}'
            '${chunk == null ? '' : ' AND id IN (${List.filled(chunk.length, '?').join(',')})'}',
        whereArgs: [cutoff, ...?chunk],
      );
      result.addAll(rows.map(NewsReadBucketMeta.fromMap));
    }
    return result;
  }

  Future<NewsReadBucket?> getReadBucket(String id) async {
    final db = await _getDb();
    final rows = await db.query(
      readBucketsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : NewsReadBucket.fromMap(rows.first);
  }

  Future<void> savePulledReadBucket(
    String id,
    int updatedAt,
    Map<String, int> reads,
  ) async {
    final db = await _getDb();
    final cutoff = DateTime.now().millisecondsSinceEpoch - readRetentionMs;
    await db.transaction((txn) async {
      final current = await txn.query(
        readBucketsTable,
        columns: ['updated_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (current.isNotEmpty &&
          (current.first['updated_at'] as int) >= updatedAt) {
        return;
      }
      await txn.rawInsert(
        'INSERT INTO ${txn.nameTable(readBucketsTable)} (id, updated_at, synced, reads) VALUES (?, ?, 1, ?) '
        'ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at, synced = 1, reads = excluded.reads',
        [id, updatedAt, jsonEncode(reads)],
      );
      for (final entry in reads.entries) {
        if (entry.value < cutoff) continue;
        await txn.rawInsert(
          'INSERT INTO ${txn.nameTable(readMarksTable)} (guid_key, read_at) VALUES (?, ?) '
          'ON CONFLICT(guid_key) DO UPDATE SET read_at = MAX(read_at, excluded.read_at)',
          [entry.key, entry.value],
        );
        await txn.update(
          articlesTable,
          {'read_at': entry.value},
          where: 'guid_key = ? AND read_at IS NULL',
          whereArgs: [entry.key],
        );
      }
    });
  }

  Future<void> markReadBucketSynced(String id, int updatedAt) async {
    final db = await _getDb();
    await db.update(
      readBucketsTable,
      {'synced': 1},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, updatedAt],
    );
  }

  Future<void> resetAfterDatabaseRestore() async {
    _dbFuture = null;
    _writerFuture = null;
    final db = await _getDb();
    final writer = '${generateShortId()}${generateShortId()}';
    final cutoff = DateTime.now().millisecondsSinceEpoch - readRetentionMs;
    await db.transaction((txn) async {
      final rows = await txn.query(readBucketsTable, where: 'synced = 0');
      final pending = rows.map(NewsReadBucket.fromMap).toList();
      await txn.delete(readBucketsTable, where: 'synced = 0');
      await txn.executor.rawInsert(
        'INSERT INTO tool_settings (tool_id, key, value, updated_at) VALUES (?, ?, ?, ?) '
        'ON CONFLICT(tool_id, key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
        [
          NewsTool.config.id,
          'read_writer_id',
          writer,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      await txn.executor.delete(
        'tool_settings',
        where: 'tool_id = ? AND key LIKE ?',
        whereArgs: [NewsTool.config.id, 'sync_cursor_%'],
      );
      final byDay = <int, Map<String, int>>{};
      for (final bucket in pending) {
        for (final entry in bucket.reads.entries) {
          if (entry.value >= cutoff) {
            byDay.putIfAbsent(entry.value ~/ _dayMs, () => {})[entry.key] =
                entry.value;
          }
        }
      }
      for (final reads in byDay.values) {
        await _addReadEntries(txn, writer, reads);
      }
    });
  }

  Future<List<NewsSource>> getSyncRecords() async {
    final db = await _getDb();
    final rows = await db.query(sourcesTable);
    return rows.map(NewsSource.fromMap).toList();
  }

  Future<NewsSource?> getSourceForSync(String shortId) async {
    final db = await _getDb();
    final rows = await db.query(
      sourcesTable,
      where: 'short_id = ?',
      whereArgs: [shortId],
      limit: 1,
    );
    return rows.isEmpty ? null : NewsSource.fromMap(rows.first);
  }

  Future<void> savePulledSource(
    NewsSource source, {
    required bool deleted,
  }) async {
    final db = await _getDb();
    if (deleted) {
      await hardDeleteSource(source.shortId);
      return;
    }
    final existing = await getSourceForSync(source.shortId);
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
