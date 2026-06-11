import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rhttp/rhttp.dart';

/// Interface for individual tool databases/stores to integrate with the sync engine.
abstract class SyncDelegate {
  String get toolId;

  Future<List<Map<String, dynamic>>> getLocalSyncRecords();

  Future<Map<String, dynamic>?> getLocalRecordData(String id);

  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  });

  Future<void> finalizeLocalSync(String id, bool wasDeleted);
}

class SyncService {
  static const String _logPrefix = '[SyncService]';

  static http.Client? _sharedClient;

  static Future<http.Client> get _client async {
    _sharedClient ??= await RhttpCompatibleClient.create();
    return _sharedClient!;
  }

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
      debugPrint('$_logPrefix Backend check failed: $e');
      return false;
    }
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

    final available = await isBackendAvailable(sanitizedUrl);
    if (!available) {
      throw Exception('Backend server unreachable');
    }

    final client = await _client;

    final metadataUri = Uri.parse('$sanitizedUrl/api/sync/$toolId/metadata');
    final metadataResponse = await client.get(metadataUri);
    if (metadataResponse.statusCode != 200) {
      throw Exception(
        'Failed to fetch metadata from server: ${metadataResponse.statusCode}',
      );
    }

    final Map<String, dynamic> metadataJson = jsonDecode(metadataResponse.body);
    if (metadataJson['success'] != true) {
      throw Exception('Server returned success=false for metadata');
    }

    final List<dynamic> serverMetaList = metadataJson['records'] ?? [];

    final Map<String, _ServerMeta> serverMetaMap = {};
    for (final item in serverMetaList) {
      final id = item['id'] as String;
      serverMetaMap[id] = _ServerMeta(
        id: id,
        updatedAt: item['updatedAt'] as int? ?? 0,
        deleted: item['deleted'] as bool? ?? false,
      );
    }

    final List<Map<String, dynamic>> localMetaList = await delegate
        .getLocalSyncRecords();
    final Map<String, _LocalMeta> localMetaMap = {
      for (final item in localMetaList)
        item['id'] as String: _LocalMeta(
          id: item['id'] as String,
          updatedAt: item['updatedAt'] as int? ?? 0,
          deleted: item['deleted'] as bool? ?? false,
        ),
    };

    final List<String> toPullIds = [];
    final List<Map<String, dynamic>> toPush = [];

    for (final sMeta in serverMetaMap.values) {
      final lMeta = localMetaMap[sMeta.id];

      if (sMeta.deleted) {
        if (lMeta != null) {
          await delegate.finalizeLocalSync(sMeta.id, true);
          deletedCount++;
        }
        continue;
      }

      if (lMeta == null || sMeta.updatedAt > lMeta.updatedAt) {
        toPullIds.add(sMeta.id);
      }
    }

    for (final lMeta in localMetaMap.values) {
      final sMeta = serverMetaMap[lMeta.id];

      if (lMeta.deleted) {
        if (sMeta == null || lMeta.updatedAt > sMeta.updatedAt) {
          toPush.add({
            'id': lMeta.id,
            'updatedAt': lMeta.updatedAt,
            'deleted': true,
          });
        }
      } else {
        if (sMeta == null || lMeta.updatedAt > sMeta.updatedAt) {
          final data = await delegate.getLocalRecordData(lMeta.id);
          toPush.add({
            'id': lMeta.id,
            'data': data ?? {},
            'updatedAt': lMeta.updatedAt,
            'deleted': false,
          });
        }
      }
    }

    if (toPullIds.isEmpty && toPush.isEmpty) {
      return {
        'pulled': pulledCount,
        'pushed': pushedCount,
        'deleted': deletedCount,
      };
    }

    List<dynamic> pulledRecords = [];
    if (toPullIds.isNotEmpty) {
      final pullUri = Uri.parse('$sanitizedUrl/api/sync/$toolId/pull');
      final pullResponse = await client.post(
        pullUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ids': toPullIds}),
      );

      if (pullResponse.statusCode != 200) {
        throw Exception(
          'Failed to pull records from server: ${pullResponse.statusCode}',
        );
      }

      final Map<String, dynamic> pullJson = jsonDecode(pullResponse.body);
      if (pullJson['success'] != true) {
        throw Exception('Server returned success=false for pull request');
      }

      pulledRecords = pullJson['records'] ?? [];
    }

    for (final sRec in pulledRecords) {
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

    if (toPush.isNotEmpty) {
      final pushUri = Uri.parse('$sanitizedUrl/api/sync/$toolId');
      final pushResponse = await client.post(
        pushUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'records': toPush}),
      );

      if (pushResponse.statusCode != 200) {
        throw Exception(
          'Failed to push records to server: ${pushResponse.statusCode}',
        );
      }

      final Map<String, dynamic> pushJson = jsonDecode(pushResponse.body);
      if (pushJson['success'] != true) {
        throw Exception('Server returned success=false for push request');
      }

      for (final pushItem in toPush) {
        final String id = pushItem['id'] as String;
        final bool isDel = pushItem['deleted'] as bool;
        await delegate.finalizeLocalSync(id, isDel);
        pushedCount++;
      }
    }

    return {
      'pulled': pulledCount,
      'pushed': pushedCount,
      'deleted': deletedCount,
    };
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
