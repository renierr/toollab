import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'totp_crypto.dart';

class TotpPasswordRotation {
  TotpPasswordRotation({
    required this.baseUrl,
    required this.userId,
    required this.checkSession,
  });

  final String baseUrl;
  final String userId;
  final void Function() checkSession;

  String get _base => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  String get _namespace => userId.trim().isEmpty
      ? TotpAuthTool.config.id
      : '${TotpAuthTool.config.id}-${userId.trim()}';

  Future<Map<String, int>> _metadata() async {
    final client = await AppHttpClient.client;
    final result = <String, int>{};
    String? cursor;
    var hasMore = false;
    do {
      checkSession();
      final response = await client
          .get(
            Uri.parse(
              '$_base/api/sync/$_namespace/metadata',
            ).replace(queryParameters: {'limit': '500', 'cursor': ?cursor}),
          )
          .timeout(const Duration(seconds: 10));
      checkSession();
      if (response.statusCode != 200) {
        throw StateError('Failed to read sync metadata');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true ||
          data['full'] == false ||
          data['records'] is! List) {
        throw StateError('Incomplete sync metadata');
      }
      for (final item in data['records'] as List) {
        if (item is! Map ||
            item['id'] is! String ||
            item['updatedAt'] is! int ||
            item['deleted'] is! bool) {
          throw const FormatException('Invalid sync metadata');
        }
        if (item['deleted'] == false) {
          if (result.containsKey(item['id'])) {
            throw const FormatException('Duplicate sync record');
          }
          result[item['id'] as String] = item['updatedAt'] as int;
        }
      }
      hasMore = data['hasMore'] == true;
      final next = (data['nextCursor'] ?? data['cursor']) as String?;
      if (hasMore && (next == null || next == cursor)) {
        throw StateError('Incomplete sync metadata');
      }
      cursor = next;
    } while (hasMore);
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _pull(List<String> ids) async {
    final result = <String, Map<String, dynamic>>{};
    for (var start = 0; start < ids.length; start += 500) {
      checkSession();
      final end = (start + 500).clamp(0, ids.length);
      final batch = ids.sublist(start, end);
      final records = await SyncService.pullRecords(
        baseUrl: baseUrl,
        userId: userId,
        toolId: TotpAuthTool.config.id,
        ids: batch,
        timeout: const Duration(seconds: 10),
      );
      checkSession();
      if (records.length != batch.length || !batch.every(records.containsKey)) {
        throw StateError('Cannot verify all remote sync records');
      }
      result.addAll(records);
    }
    return result;
  }

  Future<Map<String, dynamic>> _decrypt(
    String id,
    Map<String, dynamic> data,
    String password,
  ) async {
    final expectedVersion = id == TotpCrypto.syncCheckRecordId ? 3 : 2;
    if (data['version'] != expectedVersion || data['payload'] is! String) {
      throw const SyncUnsupportedPayloadException();
    }
    final clear = await TotpCrypto.decrypt(data['payload'] as String, password);
    final account = jsonDecode(clear);
    if (account is! Map<String, dynamic> || account['id'] != id) {
      throw const FormatException('Invalid sync record');
    }
    return account;
  }

  Future<void> verifyPassword(String password) async {
    final metadata = await _metadata();
    if (metadata.isEmpty) throw StateError('No backend records to verify');
    final records = await _pull(metadata.keys.toList());
    for (final entry in records.entries) {
      checkSession();
      try {
        await _decrypt(entry.key, entry.value, password);
      } on SecretBoxAuthenticationError {
        throw const SyncPasswordMismatchException();
      }
    }
    checkSession();
  }

  Future<void> rotate(String oldPassword, String newPassword) async {
    final metadata = await _metadata();
    final records = await _pull(metadata.keys.toList());
    final oldRecords = <String, Map<String, dynamic>>{};
    for (final entry in records.entries) {
      checkSession();
      try {
        await _decrypt(entry.key, entry.value, newPassword);
      } on SecretBoxAuthenticationError {
        try {
          oldRecords[entry.key] = await _decrypt(
            entry.key,
            entry.value,
            oldPassword,
          );
        } on SecretBoxAuthenticationError {
          throw const SyncPasswordMismatchException();
        }
      }
    }
    final client = await AppHttpClient.client;
    for (final entry in oldRecords.entries) {
      checkSession();
      final updatedAt = metadata[entry.key]! + 1;
      final account = {...entry.value, 'updatedAt': updatedAt};
      final payload = await TotpCrypto.encrypt(
        jsonEncode(account),
        newPassword,
      );
      checkSession();
      final response = await client
          .post(
            Uri.parse('$_base/api/sync/$_namespace'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'records': [
                {
                  'id': entry.key,
                  'data': {
                    'version': entry.key == TotpCrypto.syncCheckRecordId
                        ? 3
                        : 2,
                    'payload': payload,
                  },
                  'updatedAt': updatedAt,
                  'deleted': false,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));
      checkSession();
      if (response.statusCode != 200) {
        throw StateError('Password rotation failed');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['updatedCount'] != 1) {
        throw StateError('Password rotation conflicted with another sync');
      }
    }
    if (!metadata.containsKey(TotpCrypto.syncCheckRecordId)) {
      checkSession();
      final payload = await TotpCrypto.encrypt(
        jsonEncode({'id': TotpCrypto.syncCheckRecordId}),
        newPassword,
      );
      checkSession();
      final response = await client
          .post(
            Uri.parse('$_base/api/sync/$_namespace'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'records': [
                {
                  'id': TotpCrypto.syncCheckRecordId,
                  'data': {'version': 3, 'payload': payload},
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  'deleted': false,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));
      checkSession();
      if (response.statusCode != 200) {
        throw StateError('Password rotation failed');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true || data['updatedCount'] != 1) {
        throw StateError('Password rotation conflicted with another sync');
      }
    }
    await verifyPassword(newPassword);
  }
}
