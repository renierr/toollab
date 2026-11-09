part of 'news_db_helper.dart';

/// Read marks and the rotating per-writer buckets that sync them.
extension NewsReadMarks on NewsDbHelper {
  Future<String> _readWriterId() => _writerFuture ??= () async {
    final db = await _getDb();
    final id = NewsDbHelper._randomId(20);
    return db.transaction((txn) async {
      await txn.executor.rawInsert(
        'INSERT OR IGNORE INTO tool_settings (tool_id, key, value, updated_at) VALUES (?, ?, ?, ?)',
        [
          NewsTool.config.id,
          NewsDbHelper._writerIdKey,
          id,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      final rows = await txn.executor.query(
        'tool_settings',
        columns: ['value'],
        where: 'tool_id = ? AND key = ?',
        whereArgs: [NewsTool.config.id, NewsDbHelper._writerIdKey],
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
    final day = entries.values.first ~/ NewsDbHelper._dayMs;
    final id =
        '${NewsDbHelper.readBucketPrefix}$writer:'
        '${day % NewsDbHelper._bucketCount}';
    final rows = await txn.query(
      NewsDbHelper.readBucketsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final old = rows.isEmpty ? null : NewsReadBucket.fromMap(rows.first);
    final reads = <String, int>{
      if (old != null)
        for (final entry in old.reads.entries)
          if (entry.value ~/ NewsDbHelper._dayMs == day) entry.key: entry.value,
    };
    for (final entry in entries.entries) {
      reads[entry.key] = entry.value;
      await txn.rawInsert(
        'INSERT INTO ${txn.nameTable(NewsDbHelper.readMarksTable)} (guid_key, read_at) VALUES (?, ?) '
        'ON CONFLICT(guid_key) DO UPDATE SET read_at = MAX(read_at, excluded.read_at)',
        [entry.key, entry.value],
      );
    }
    await txn.rawInsert(
      'INSERT INTO ${txn.nameTable(NewsDbHelper.readBucketsTable)} (id, updated_at, synced, reads) VALUES (?, ?, 0, ?) '
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
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - NewsDbHelper.readRetentionMs;
    await db.transaction((txn) async {
      await txn.delete(
        NewsDbHelper.readMarksTable,
        where: 'read_at < ?',
        whereArgs: [cutoff],
      );
      await txn.delete(
        NewsDbHelper.readBucketsTable,
        where: 'updated_at < ?',
        whereArgs: [cutoff],
      );
      final rows = await txn.rawQuery(
        'SELECT a.guid_key, a.read_at FROM ${txn.nameTable(NewsDbHelper.articlesTable)} a '
        'LEFT JOIN ${txn.nameTable(NewsDbHelper.readMarksTable)} r ON r.guid_key = a.guid_key '
        'WHERE a.read_at >= ? AND r.guid_key IS NULL',
        [cutoff],
      );
      final grouped = <int, Map<String, int>>{};
      for (final row in rows) {
        final time = row['read_at'] as int;
        grouped.putIfAbsent(
          time ~/ NewsDbHelper._dayMs,
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
      NewsDbHelper.readBucketsTable,
      where: onlyPending ? 'synced = 0 AND updated_at >= ?' : 'updated_at >= ?',
      whereArgs: [
        DateTime.now().millisecondsSinceEpoch - NewsDbHelper.readRetentionMs,
      ],
    );
    return rows.map(NewsReadBucket.fromMap).toList();
  }

  Future<List<NewsReadBucketMeta>> getReadBucketMetadata({
    bool onlyPending = false,
    List<String>? ids,
  }) async {
    final db = await _getDb();
    if (ids != null && ids.isEmpty) return [];
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - NewsDbHelper.readRetentionMs;
    final result = <NewsReadBucketMeta>[];
    const size = NewsDbHelper._chunkSize;
    final chunks = ids == null
        ? <List<String>?>[null]
        : <List<String>?>[
            for (var start = 0; start < ids.length; start += size)
              ids.sublist(start, min(start + size, ids.length)),
          ];
    for (final chunk in chunks) {
      final rows = await db.query(
        NewsDbHelper.readBucketsTable,
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
      NewsDbHelper.readBucketsTable,
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
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - NewsDbHelper.readRetentionMs;
    await db.transaction((txn) async {
      final current = await txn.query(
        NewsDbHelper.readBucketsTable,
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
        'INSERT INTO ${txn.nameTable(NewsDbHelper.readBucketsTable)} (id, updated_at, synced, reads) VALUES (?, ?, 1, ?) '
        'ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at, synced = 1, reads = excluded.reads',
        [id, updatedAt, jsonEncode(reads)],
      );
      for (final entry in reads.entries) {
        if (entry.value < cutoff) continue;
        await txn.rawInsert(
          'INSERT INTO ${txn.nameTable(NewsDbHelper.readMarksTable)} (guid_key, read_at) VALUES (?, ?) '
          'ON CONFLICT(guid_key) DO UPDATE SET read_at = MAX(read_at, excluded.read_at)',
          [entry.key, entry.value],
        );
        await txn.update(
          NewsDbHelper.articlesTable,
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
      NewsDbHelper.readBucketsTable,
      {'synced': 1},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, updatedAt],
    );
  }

  Future<void> resetAfterDatabaseRestore() async {
    _dbFuture = null;
    _writerFuture = null;
    final db = await _getDb();
    final writer = NewsDbHelper._randomId(20);
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - NewsDbHelper.readRetentionMs;
    await db.transaction((txn) async {
      final rows = await txn.query(
        NewsDbHelper.readBucketsTable,
        where: 'synced = 0',
      );
      final pending = rows.map(NewsReadBucket.fromMap).toList();
      await txn.delete(NewsDbHelper.readBucketsTable, where: 'synced = 0');
      await txn.executor.rawInsert(
        'INSERT INTO tool_settings (tool_id, key, value, updated_at) VALUES (?, ?, ?, ?) '
        'ON CONFLICT(tool_id, key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
        [
          NewsTool.config.id,
          NewsDbHelper._writerIdKey,
          writer,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      await txn.executor.delete(
        'tool_settings',
        where: 'tool_id = ? AND key LIKE ?',
        whereArgs: [NewsTool.config.id, '${NewsDbHelper.syncCursorPrefix}%'],
      );
      final byDay = <int, Map<String, int>>{};
      for (final bucket in pending) {
        for (final entry in bucket.reads.entries) {
          if (entry.value >= cutoff) {
            byDay.putIfAbsent(
              entry.value ~/ NewsDbHelper._dayMs,
              () => {},
            )[entry.key] = entry.value;
          }
        }
      }
      for (final reads in byDay.values) {
        await _addReadEntries(txn, writer, reads);
      }
    });
  }
}
