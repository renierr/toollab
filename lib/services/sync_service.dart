import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Interface for individual tool databases/stores to integrate with the sync engine.
abstract class SyncDelegate {
  /// Unique identifier of the tool (used to build the sync namespace and toolId on server).
  String get toolId;

  /// Whether this tool's sync should be namespaced with a user ID suffix.
  /// If false, the sync will use [toolId] directly without any user suffix.
  bool get useUserNamespace => true;

  /// Retrieve all local records (active and deleted) as a list of maps.
  /// Each map MUST contain:
  /// - 'id': String (the unique record ID)
  /// - 'updatedAt': int (timestamp in milliseconds)
  /// - 'deleted': bool
  Future<List<Map<String, dynamic>>> getLocalSyncRecords();

  /// Retrieve the full details for a specific local record by ID to push to the server.
  /// Returns a map representing the serialized representation of the record.
  /// This map will be sent in the 'data' field of the push payload.
  /// If the record is deleted, this can return empty map or null.
  Future<Map<String, dynamic>?> getLocalRecordData(String id);

  /// Save a record pulled from the server into the local database.
  /// The [id] is the record's unique ID.
  /// The [data] is the deserialized map containing full details of the record.
  /// The [updatedAt] is the server's update timestamp.
  /// The [deleted] indicates if the record is deleted on the server.
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  });

  /// Permanently delete or mark a record as fully synced locally.
  /// If [wasDeleted] is true, the record was deleted locally and successfully synced to server,
  /// so it can be physically deleted or marked accordingly.
  /// If [wasDeleted] is false, the record was successfully pushed/updated, so it should be marked as synced.
  Future<void> finalizeLocalSync(String id, bool wasDeleted);
}

class SyncService {
  static const String _logPrefix = '[SyncService]';

  /// Check if the backend server is reachable at the given base URL.
  static Future<bool> isBackendAvailable(String baseUrl) async {
    try {
      final sanitizedUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final uri = Uri.parse('$sanitizedUrl/api/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
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

  /// Perform bidirectional synchronization of a tool's SQLite records with the cloud backend.
  static Future<Map<String, int>> sync({
    required String baseUrl,
    required String userId,
    required SyncDelegate delegate,
  }) async {
    final String sanitizedUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final String namespaceUserId = userId.trim().isEmpty
        ? 'user-1'
        : userId.trim();
    final String toolId = delegate.useUserNamespace
        ? '${delegate.toolId}-$namespaceUserId'
        : delegate.toolId;

    int pulledCount = 0;
    int pushedCount = 0;
    int deletedCount = 0;

    // 1. Check server availability
    final available = await isBackendAvailable(sanitizedUrl);
    if (!available) {
      throw Exception('Backend server unreachable');
    }

    // 2. Fetch server metadata
    final metadataUri = Uri.parse('$sanitizedUrl/api/sync/$toolId/metadata');
    final metadataResponse = await http.get(metadataUri);
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

    // Map server metadata by record ID
    final Map<String, _ServerMeta> serverMetaMap = {};
    for (final item in serverMetaList) {
      final id = item['id'] as String;
      serverMetaMap[id] = _ServerMeta(
        id: id,
        updatedAt: item['updatedAt'] as int? ?? 0,
        deleted: item['deleted'] as bool? ?? false,
      );
    }

    // 3. Get local records (including deleted ones) — metadata only
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

    // 4. Resolve Deletions & Identify Pull Targets
    for (final sMeta in serverMetaMap.values) {
      final lMeta = localMetaMap[sMeta.id];

      if (sMeta.deleted) {
        if (lMeta != null) {
          // Delete locally right away if server has deleted it
          await delegate.finalizeLocalSync(sMeta.id, true);
          deletedCount++;
        }
        continue;
      }

      if (lMeta == null || sMeta.updatedAt > lMeta.updatedAt) {
        toPullIds.add(sMeta.id);
      }
    }

    // 5. Identify Push Targets (Local -> Server)
    for (final lMeta in localMetaMap.values) {
      final sMeta = serverMetaMap[lMeta.id];

      if (lMeta.deleted) {
        // If marked as deleted locally and either not on server, or on server but local deletion is newer
        if (sMeta == null || lMeta.updatedAt > sMeta.updatedAt) {
          toPush.add({
            'id': lMeta.id,
            'updatedAt': lMeta.updatedAt,
            'deleted': true,
          });
        }
      } else {
        // Active local record: push if not on server or if local record is newer
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

    // 6. Fast Path: Exit early if nothing to transfer!
    if (toPullIds.isEmpty && toPush.isEmpty) {
      return {
        'pulled': pulledCount,
        'pushed': pushedCount,
        'deleted': deletedCount,
      };
    }

    // 7. Delta Pulling: Retrieve only full records that changed
    List<dynamic> pulledRecords = [];
    if (toPullIds.isNotEmpty) {
      final pullUri = Uri.parse('$sanitizedUrl/api/sync/$toolId/pull');
      final pullResponse = await http.post(
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

    // 8. Merge Pulled Records -> Local Database
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
        final Map<String, dynamic> data =
            sRec['data'] as Map<String, dynamic>? ?? {};
        await delegate.savePulledRecord(
          id: id,
          data: data,
          updatedAt: serverUpdatedAt,
          deleted: false,
        );
        pulledCount++;
      }
    }

    // 9. Push Local Changes to Server
    if (toPush.isNotEmpty) {
      final pushUri = Uri.parse('$sanitizedUrl/api/sync/$toolId');
      final pushResponse = await http.post(
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

      // Finalize database states locally
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
