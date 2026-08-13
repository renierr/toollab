import 'dart:convert';
import 'dart:math';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:http/http.dart' as http;
import 'app_http_client.dart';

/// Interface for individual tool databases/stores to integrate with the sync engine.
abstract class SyncDelegate {
  String get toolId;

  Future<List<Map<String, dynamic>>> getLocalSyncRecords();

  Future<List<Map<String, dynamic>>> getLocalSyncRecordsByIds(List<String> ids);

  Future<List<Map<String, dynamic>>> getLocalPendingSyncRecords();

  Future<String?> getSyncCursor(String syncId);

  Future<void> saveSyncCursor(String syncId, String cursor);

  Future<Map<String, dynamic>?> getLocalRecordData(String id);

  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  });

  Future<void> finalizeLocalSync(String id, bool wasDeleted);
}

mixin DefaultSyncDelegate implements SyncDelegate {
  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecordsByIds(
    List<String> ids,
  ) async => (await getLocalSyncRecords())
      .where((record) => ids.contains(record['id']))
      .toList();

  @override
  Future<List<Map<String, dynamic>>> getLocalPendingSyncRecords() async =>
      getLocalSyncRecords();

  @override
  Future<String?> getSyncCursor(String syncId) async => null;

  @override
  Future<void> saveSyncCursor(String syncId, String cursor) async {}
}

/// What the backend stores for one tool namespace. [toolId] is the server-side
/// namespace, so it carries the `-<userId>` suffix when one is configured.
class SyncToolStats {
  final String toolId;
  final int records;
  final int deleted;
  final int dataBytes;
  final int binaryRecords;
  final int binaryBytes;
  final int? lastUpdatedAt;

  const SyncToolStats({
    required this.toolId,
    required this.records,
    required this.deleted,
    required this.dataBytes,
    required this.binaryRecords,
    required this.binaryBytes,
    this.lastUpdatedAt,
  });

  int get totalBytes => dataBytes + binaryBytes;

  factory SyncToolStats.fromJson(Map<String, dynamic> json) => SyncToolStats(
    toolId: json['toolId'] as String? ?? '',
    records: (json['records'] as num?)?.toInt() ?? 0,
    deleted: (json['deleted'] as num?)?.toInt() ?? 0,
    dataBytes: (json['dataBytes'] as num?)?.toInt() ?? 0,
    binaryRecords: (json['binaryRecords'] as num?)?.toInt() ?? 0,
    binaryBytes: (json['binaryBytes'] as num?)?.toInt() ?? 0,
    lastUpdatedAt: (json['lastUpdatedAt'] as num?)?.toInt(),
  );
}

class SyncStats {
  final List<SyncToolStats> tools;

  const SyncStats({required this.tools});

  int get records => tools.fold(0, (sum, t) => sum + t.records);
  int get deleted => tools.fold(0, (sum, t) => sum + t.deleted);
  int get dataBytes => tools.fold(0, (sum, t) => sum + t.dataBytes);
  int get binaryBytes => tools.fold(0, (sum, t) => sum + t.binaryBytes);
  int get binaryRecords => tools.fold(0, (sum, t) => sum + t.binaryRecords);
  int get totalBytes => dataBytes + binaryBytes;
}

class SyncService {
  static const String _logPrefix = '[SyncService]';
  static const _syncBatchSize = 500;

  /// Measured in JSON characters, not bytes, so multi-byte text inflates the
  /// real payload. Kept far below the backend's request ceiling to absorb that.
  static const _syncMaxPushChars = 4 * 1024 * 1024;

  static Future<http.Client> get _client => AppHttpClient.client;

  static Future<bool> isBackendAvailable(String baseUrl) async {
    try {
      final sanitizedUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final uri = Uri.parse('$sanitizedUrl/api/health');
      final client = await _client;
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['status'] == 'ok';
      }
      return false;
    } catch (e) {
      errorLog('$_logPrefix Backend check failed: $e');
      return false;
    }
  }

  /// Storage figures the backend reports per tool, or null when this server has
  /// no `/api/sync/stats` route. An older backend answers 404 there, and that is
  /// a missing feature rather than a failure, so it must not read as an error.
  /// Transport problems still throw - those the user can act on.
  static Future<SyncStats?> fetchStats(String baseUrl) async {
    final sanitizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final client = await _client;
    final response = await client
        .get(Uri.parse('$sanitizedUrl/api/sync/stats'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch sync stats: ${_serverError(response)}');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    // A server that routed /stats onto its /:toolId handler answers 200 with a
    // record list instead, which is the same "no such route" case.
    if (json['success'] != true || json['tools'] is! List) return null;

    return SyncStats(
      tools: (json['tools'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(SyncToolStats.fromJson)
          .toList(),
    );
  }

  /// The backend answers a rejection with `{success: false, error: …}`, which
  /// says which limit was hit. Reporting the bare status code instead leaves a
  /// 413 indistinguishable between "too many records" and "payload too large".
  static String _serverError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) {
        return '${response.statusCode} ${body['error']}';
      }
    } catch (_) {
      // Not JSON; the status code is all there is.
    }
    return '${response.statusCode}';
  }

  /// Recursively unwraps `{__type: 'blob', data: …}` Maps produced by the
  /// browser-toolkit backend, replacing them with the raw base64 data string.
  /// This ensures all [SyncDelegate]s receive plain data regardless of source.
  static Map<String, dynamic> _unwrapBlobData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final val = entry.value;
      if (val is Map<String, dynamic>) {
        if (val['__type'] == 'blob' && val['data'] is String) {
          result[entry.key] = val['data'];
        } else {
          result[entry.key] = _unwrapBlobData(val);
        }
      } else if (val is List) {
        result[entry.key] = val.map((e) {
          if (e is Map<String, dynamic>) {
            if (e['__type'] == 'blob' && e['data'] is String) return e['data'];
            return _unwrapBlobData(e);
          }
          return e;
        }).toList();
      } else {
        result[entry.key] = val;
      }
    }
    return result;
  }

  static Future<Map<String, int>> sync({
    required String baseUrl,
    required String userId,
    required SyncDelegate delegate,
    bool backendAlreadyChecked = false,
  }) async {
    final String sanitizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final String toolId = userId.trim().isEmpty
        ? delegate.toolId
        : '${delegate.toolId}-${userId.trim()}';

    int pulledCount = 0;
    int pushedCount = 0;
    int deletedCount = 0;

    if (!backendAlreadyChecked) {
      final available = await isBackendAvailable(sanitizedUrl);
      if (!available) {
        throw Exception('Backend server unreachable');
      }
    }

    final client = await _client;

    const httpTimeout = Duration(seconds: 10);

    final metadataUri = Uri.parse('$sanitizedUrl/api/sync/$toolId/metadata');
    final cursor = await delegate.getSyncCursor(toolId);
    String? pageCursor = cursor;
    String? nextCursor;
    var fullMetadata = true;
    var hasMoreMetadata = false;
    var truncatedMetadata = false;
    final serverMetaList = <dynamic>[];
    do {
      final query = <String, String>{'limit': '$_syncBatchSize'};
      if (pageCursor != null) query['cursor'] = pageCursor;
      final metadataResponse = await client
          .get(metadataUri.replace(queryParameters: query))
          .timeout(httpTimeout);
      if (metadataResponse.statusCode != 200) {
        throw Exception(
          'Failed to fetch metadata from server: '
          '${_serverError(metadataResponse)}',
        );
      }
      final Map<String, dynamic> metadataJson = jsonDecode(
        metadataResponse.body,
      );
      if (metadataJson['success'] != true) {
        throw Exception('Server returned success=false for metadata');
      }
      serverMetaList.addAll(
        metadataJson['records'] as List<dynamic>? ?? const [],
      );
      fullMetadata = metadataJson['full'] as bool? ?? true;
      nextCursor = metadataJson['cursor'] as String?;
      hasMoreMetadata = metadataJson['hasMore'] as bool? ?? false;
      final advanced = metadataJson['nextCursor'] as String? ?? nextCursor;
      // A server reporting hasMore without advancing the cursor would re-fetch
      // the same page forever and grow serverMetaList without bound.
      if (hasMoreMetadata && (advanced == null || advanced == pageCursor)) {
        // Saving the cursor here would mark unseen records as already synced,
        // so the run stays incomplete and retries from the old cursor instead.
        truncatedMetadata = true;
        debugLog(
          '$_logPrefix Server reported more metadata without advancing the '
          'cursor; stopping pagination for $toolId',
        );
        break;
      }
      pageCursor = advanced;
    } while (hasMoreMetadata);

    final Map<String, _ServerMeta> serverMetaMap = {};
    for (final item in serverMetaList) {
      final id = item['id'] as String;
      serverMetaMap[id] = _ServerMeta(
        id: id,
        updatedAt: item['updatedAt'] as int? ?? 0,
        deleted: item['deleted'] as bool? ?? false,
      );
    }

    final List<Map<String, dynamic>> localMetaList = fullMetadata
        ? await delegate.getLocalSyncRecords()
        : await delegate.getLocalSyncRecordsByIds(serverMetaMap.keys.toList());
    final pendingMetaList = fullMetadata
        ? const <Map<String, dynamic>>[]
        : await delegate.getLocalPendingSyncRecords();
    final Map<String, _LocalMeta> localMetaMap = {
      for (final item in [...localMetaList, ...pendingMetaList])
        item['id'] as String: _LocalMeta(
          id: item['id'] as String,
          updatedAt: item['updatedAt'] as int? ?? 0,
          deleted: item['deleted'] as bool? ?? false,
        ),
    };

    final List<String> toPullIds = [];
    final List<_LocalMeta> toPush = [];

    for (final sMeta in serverMetaMap.values) {
      final lMeta = localMetaMap[sMeta.id];

      if (sMeta.deleted) {
        // A stale server tombstone must not erase a record changed locally
        // after the deletion was written. The newer local record is pushed below.
        if (lMeta != null && sMeta.updatedAt >= lMeta.updatedAt) {
          await delegate.finalizeLocalSync(sMeta.id, true);
          deletedCount++;
        }
        continue;
      }

      if (lMeta == null || sMeta.updatedAt > lMeta.updatedAt) {
        toPullIds.add(sMeta.id);
      }
    }

    final pushCandidates = fullMetadata
        ? localMetaMap.values
        : pendingMetaList.map(
            (item) => _LocalMeta(
              id: item['id'] as String,
              updatedAt: item['updatedAt'] as int? ?? 0,
              deleted: item['deleted'] as bool? ?? false,
            ),
          );
    // Only the metadata is collected here. Payloads are read per batch in
    // [_pushBatches] so a bulk import never holds every record in memory.
    for (final lMeta in pushCandidates) {
      final sMeta = serverMetaMap[lMeta.id];
      if (sMeta == null || lMeta.updatedAt > sMeta.updatedAt) {
        toPush.add(lMeta);
      }
    }

    if (toPullIds.isEmpty && toPush.isEmpty) {
      if (nextCursor != null && !truncatedMetadata) {
        await delegate.saveSyncCursor(toolId, nextCursor);
      }
      return {
        'pulled': pulledCount,
        'pushed': pushedCount,
        'deleted': deletedCount,
      };
    }

    if (toPullIds.isNotEmpty) {
      final pullUri = Uri.parse('$sanitizedUrl/api/sync/$toolId/pull');
      for (final ids in _batches(toPullIds, _syncBatchSize)) {
        final pullResponse = await client
            .post(
              pullUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'ids': ids}),
            )
            .timeout(httpTimeout);

        if (pullResponse.statusCode != 200) {
          throw Exception(
            'Failed to pull records from server: ${_serverError(pullResponse)}',
          );
        }

        final Map<String, dynamic> pullJson = jsonDecode(pullResponse.body);
        if (pullJson['success'] != true) {
          throw Exception('Server returned success=false for pull request');
        }
        // Applied per batch so the decoded payloads can be released before the
        // next page is fetched.
        for (final sRec in pullJson['records'] as List<dynamic>? ?? const []) {
          final String id = sRec['id'] as String;
          final bool serverDeleted = sRec['deleted'] as bool? ?? false;
          final int serverUpdatedAt = sRec['updatedAt'] as int? ?? 0;

          final lMeta = localMetaMap[id];

          if (serverDeleted) {
            if (lMeta != null) {
              await delegate.finalizeLocalSync(id, true);
              deletedCount++;
            }
            continue;
          }

          if (lMeta == null || serverUpdatedAt > lMeta.updatedAt) {
            final Map<String, dynamic> data = _unwrapBlobData(
              sRec['data'] as Map<String, dynamic>? ?? {},
            );
            await delegate.savePulledRecord(
              id: id,
              data: data,
              updatedAt: serverUpdatedAt,
              deleted: false,
            );
            pulledCount++;
          }
        }
      }
    }

    if (toPush.isNotEmpty) {
      final pushUri = Uri.parse('$sanitizedUrl/api/sync/$toolId');
      await for (final records in _pushBatches(delegate, toPush)) {
        final pushResponse = await client
            .post(
              pushUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'records': records}),
            )
            .timeout(httpTimeout);

        if (pushResponse.statusCode != 200) {
          throw Exception(
            'Failed to push records to server: ${_serverError(pushResponse)}',
          );
        }

        final Map<String, dynamic> pushJson = jsonDecode(pushResponse.body);
        if (pushJson['success'] != true) {
          throw Exception('Server returned success=false for push request');
        }

        for (final pushItem in records) {
          final String id = pushItem['id'] as String;
          final bool isDel = pushItem['deleted'] as bool;
          await delegate.finalizeLocalSync(id, isDel);
          pushedCount++;
        }
      }
    }

    if (nextCursor != null && !truncatedMetadata) {
      await delegate.saveSyncCursor(toolId, nextCursor);
    }
    return {
      'pulled': pulledCount,
      'pushed': pushedCount,
      'deleted': deletedCount,
    };
  }

  /// Materializes push payloads one batch at a time, capping a batch by record
  /// count and by encoded size. Blob-carrying tools (chiptune, signatures,
  /// sketch board) blow past any request limit long before the count cap, and a
  /// rejected batch fails the whole sync. A record larger than the cap is sent
  /// on its own rather than dropped.
  static Stream<List<Map<String, dynamic>>> _pushBatches(
    SyncDelegate delegate,
    List<_LocalMeta> metas,
  ) async* {
    var batch = <Map<String, dynamic>>[];
    var batchSize = 0;

    for (final meta in metas) {
      final record = meta.deleted
          ? <String, dynamic>{
              'id': meta.id,
              'updatedAt': meta.updatedAt,
              'deleted': true,
            }
          : <String, dynamic>{
              'id': meta.id,
              'data': await delegate.getLocalRecordData(meta.id) ?? {},
              'updatedAt': meta.updatedAt,
              'deleted': false,
            };
      final size = jsonEncode(record).length;

      if (batch.isNotEmpty &&
          (batch.length >= _syncBatchSize ||
              batchSize + size > _syncMaxPushChars)) {
        yield batch;
        batch = <Map<String, dynamic>>[];
        batchSize = 0;
      }

      batch.add(record);
      batchSize += size;
    }

    if (batch.isNotEmpty) yield batch;
  }

  static Iterable<List<T>> _batches<T>(List<T> values, int size) sync* {
    for (var start = 0; start < values.length; start += size) {
      final end = min(start + size, values.length);
      yield values.sublist(start, end);
    }
  }
}

class _ServerMeta {
  final String id;
  final int updatedAt;
  final bool deleted;

  _ServerMeta({
    required this.id,
    required this.updatedAt,
    required this.deleted,
  });
}

class _LocalMeta {
  final String id;
  final int updatedAt;
  final bool deleted;

  _LocalMeta({
    required this.id,
    required this.updatedAt,
    required this.deleted,
  });
}
