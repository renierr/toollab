import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/news/config.dart';

import 'news_db_helper.dart';
import 'news_source.dart';

class NewsSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  final Map<String, int> _versions = {};
  @override
  String get toolId => NewsTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    await NewsDbHelper.instance.prepareReadSync();
    final records = await NewsDbHelper.instance.getSyncRecords();
    final buckets = await NewsDbHelper.instance.getReadBucketMetadata();
    final result = [
      for (final record in records)
        {
          'id': record.shortId,
          'updatedAt': record.updatedAt,
          'deleted': record.deleted,
        },
      for (final bucket in buckets)
        {'id': bucket.id, 'updatedAt': bucket.updatedAt, 'deleted': false},
    ];
    for (final record in result) {
      _versions[record['id'] as String] = record['updatedAt'] as int;
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalPendingSyncRecords() async {
    await NewsDbHelper.instance.prepareReadSync();
    final sources = await NewsDbHelper.instance.getSyncRecords();
    final buckets = await NewsDbHelper.instance.getReadBucketMetadata(
      onlyPending: true,
    );
    final result = [
      for (final source in sources)
        if (!source.synced)
          {
            'id': source.shortId,
            'updatedAt': source.updatedAt,
            'deleted': source.deleted,
          },
      for (final bucket in buckets)
        {'id': bucket.id, 'updatedAt': bucket.updatedAt, 'deleted': false},
    ];
    for (final record in result) {
      _versions[record['id'] as String] = record['updatedAt'] as int;
    }
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecordsByIds(
    List<String> ids,
  ) async {
    final wanted = ids.toSet();
    final sources = await NewsDbHelper.instance.getSyncRecords();
    final buckets = await NewsDbHelper.instance.getReadBucketMetadata(ids: ids);
    final result = [
      for (final source in sources)
        if (wanted.contains(source.shortId))
          {
            'id': source.shortId,
            'updatedAt': source.updatedAt,
            'deleted': source.deleted,
          },
      for (final bucket in buckets)
        {'id': bucket.id, 'updatedAt': bucket.updatedAt, 'deleted': false},
    ];
    for (final record in result) {
      _versions[record['id'] as String] = record['updatedAt'] as int;
    }
    return result;
  }

  @override
  Future<String?> getSyncCursor(String syncId) =>
      DatabaseService.instance.getSetting(toolId, 'sync_cursor_$syncId');

  @override
  Future<void> saveSyncCursor(String syncId, String cursor) => DatabaseService
      .instance
      .setSetting(toolId, 'sync_cursor_$syncId', cursor);

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    if (id.startsWith(NewsDbHelper.readBucketPrefix)) {
      final bucket = await NewsDbHelper.instance.getReadBucket(id);
      if (bucket == null) return null;
      return {'reads': bucket.reads};
    }
    final source = await NewsDbHelper.instance.getSourceForSync(id);
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
    if (id.startsWith(NewsDbHelper.readBucketPrefix)) {
      if (version != null && !wasDeleted) {
        await NewsDbHelper.instance.markReadBucketSynced(id, version);
      }
      return;
    }
    if (wasDeleted) {
      if (version != null) {
        await NewsDbHelper.instance.hardDeleteSource(id, updatedAt: version);
      }
    } else {
      if (version != null) {
        await NewsDbHelper.instance.markSourceSynced(id, updatedAt: version);
      }
    }
  }
}
