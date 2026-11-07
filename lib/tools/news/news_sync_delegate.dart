import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/news/config.dart';

import 'news_db_helper.dart';
import 'news_source.dart';

class NewsSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  @override
  String get toolId => NewsTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final records = await NewsDbHelper.instance.getSyncRecords();
    return [
      for (final record in records)
        {
          'id': record.shortId,
          'updatedAt': record.updatedAt,
          'deleted': record.deleted,
        },
    ];
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
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
    if (wasDeleted) {
      await NewsDbHelper.instance.hardDeleteSource(id);
    } else {
      await NewsDbHelper.instance.markSourceSynced(id);
    }
  }
}
