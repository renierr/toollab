import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'news_db_helper.dart';
import 'news_read_bucket.dart';
import 'news_source.dart';

class NewsSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  final Map<String, int> _versions = {};

  @override
  String get toolId => NewsTool.config.id;

  /// Remembers each offered version so [finalizeLocalSync] only clears the
  /// pending flag of the version that was actually pushed.
  List<Map<String, dynamic>> _records(
    Iterable<NewsSource> sources,
    Iterable<NewsReadBucketMeta> buckets,
  ) {
    Map<String, dynamic> track(String id, int updatedAt, bool deleted) {
      _versions[id] = updatedAt;
      return {'id': id, 'updatedAt': updatedAt, 'deleted': deleted};
    }

    return [
      for (final source in sources)
        track(source.shortId, source.updatedAt, source.deleted),
      for (final bucket in buckets) track(bucket.id, bucket.updatedAt, false),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final db = NewsDbHelper.instance;
    await db.prepareReadSync();
    return _records(
      await db.getSyncRecords(),
      await db.getReadBucketMetadata(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalPendingSyncRecords() async {
    final db = NewsDbHelper.instance;
    await db.prepareReadSync();
    final sources = await db.getSyncRecords();
    return _records(
      sources.where((source) => !source.synced),
      await db.getReadBucketMetadata(onlyPending: true),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecordsByIds(
    List<String> ids,
  ) async {
    final db = NewsDbHelper.instance;
    final wanted = ids.toSet();
    final sources = await db.getSyncRecords();
    return _records(
      sources.where((source) => wanted.contains(source.shortId)),
      await db.getReadBucketMetadata(ids: ids),
    );
  }

  @override
  Future<String?> getSyncCursor(String syncId) => DatabaseService.instance
      .getSetting(toolId, '${NewsDbHelper.syncCursorPrefix}$syncId');

  @override
  Future<void> saveSyncCursor(String syncId, String cursor) => DatabaseService
      .instance
      .setSetting(toolId, '${NewsDbHelper.syncCursorPrefix}$syncId', cursor);

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    if (id.startsWith(NewsDbHelper.readBucketPrefix)) {
      final bucket = await NewsDbHelper.instance.getReadBucket(id);
      if (bucket == null) return null;
      return {'reads': bucket.reads};
    }
    final source = await NewsDbHelper.instance.getSource(id);
    if (source == null || source.deleted) return null;
    return source.toSyncJson();
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    if (id.startsWith(NewsDbHelper.readBucketPrefix)) {
      if (deleted || data['reads'] is! Map) return;
      final raw = data['reads'] as Map;
      final reads = <String, int>{};
      for (final entry in raw.entries) {
        if (entry.key is String &&
            entry.value is int &&
            (entry.key as String).length <= 128) {
          reads[entry.key as String] = entry.value as int;
        }
      }
      await NewsDbHelper.instance.savePulledReadBucket(id, updatedAt, reads);
      return;
    }
    final feedUrl = data['feedUrl'] as String? ?? '';
    if (!deleted && feedUrl.isEmpty) return;
    await NewsDbHelper.instance.savePulledSource(
      NewsSource(
        shortId: id,
        title: data['title'] as String? ?? '',
        feedUrl: feedUrl,
        siteUrl: data['siteUrl'] as String? ?? '',
        category: data['category'] as String? ?? '',
        enabled: data['enabled'] as bool? ?? true,
        sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
        createdAt: (data['createdAt'] as num?)?.toInt() ?? updatedAt,
        updatedAt: updatedAt,
      ),
      deleted: deleted,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    final version = _versions.remove(id);
    if (version == null) return;
    final db = NewsDbHelper.instance;
    if (id.startsWith(NewsDbHelper.readBucketPrefix)) {
      if (!wasDeleted) await db.markReadBucketSynced(id, version);
    } else if (wasDeleted) {
      await db.hardDeleteSource(id, updatedAt: version);
    } else {
      await db.markSourceSynced(id, updatedAt: version);
    }
  }
}
