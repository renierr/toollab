import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';

import 'config.dart';
import 'totp_account.dart';
import 'totp_crypto.dart';
import 'totp_vault_store.dart';

class TotpSyncDelegate
    with DefaultSyncDelegate
    implements
        SyncDelegate,
        SyncPreflightDelegate,
        SyncSessionGuard,
        SyncControlRecordDelegate {
  static String get _toolId => TotpAuthTool.config.id;

  final _vault = TotpVaultStore();
  final _legacyRemoteIds = <String>{};
  ToolLockSession? _runSession;

  @override
  void beginSyncSession() {
    _runSession = ToolLockController.sessionFor(_toolId);
    _legacyRemoteIds.clear();
  }

  @override
  bool get syncSessionValid =>
      _runSession != null &&
      identical(_runSession, ToolLockController.sessionFor(_toolId));

  ToolLockSession _session() {
    final session = ToolLockController.sessionFor(_toolId);
    if (session == null || (_runSession != null && !syncSessionValid)) {
      throw StateError('Vault is locked');
    }
    return session;
  }

  /// Re-reads the stored password so a password set after startup applies to
  /// the next run.
  @override
  Future<bool> isReadyToSync() async {
    return ToolLockController.sessionFor(_toolId) != null &&
        await DatabaseService.instance.getSetting(
              _toolId,
              TotpVaultStore.rotationSetting,
            ) ==
            null;
  }

  Future<String> _requiredPassword() async {
    return _session().password;
  }

  Future<Map<String, dynamic>> _decryptRecord(Map<String, dynamic> data) async {
    if (TotpLegacySyncRecord.matches(data)) {
      return TotpLegacySyncRecord.decode(data, await _requiredPassword());
    }
    if ((data['version'] != 2 && data['version'] != 3) ||
        data['payload'] is! String) {
      throw const SyncUnsupportedPayloadException();
    }
    final password = await _requiredPassword();
    try {
      final clear = await TotpCrypto.decrypt(
        data['payload'] as String,
        password,
      );
      final decoded = jsonDecode(clear);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid sync record');
      }
      if ((data['version'] == 3) !=
          (decoded['id'] == TotpCrypto.syncCheckRecordId)) {
        throw const SyncUnsupportedPayloadException();
      }
      return decoded;
    } on SecretBoxAuthenticationError {
      throw const SyncPasswordMismatchException();
    }
  }

  @override
  bool isSyncControlRecord(String id) => id == TotpCrypto.syncCheckRecordId;

  @override
  List<String> get controlRecordIds => const [TotpCrypto.syncCheckRecordId];

  @override
  Future<void> verifyRemotePayloads(
    Map<String, Map<String, dynamic>> records,
  ) async {
    for (final entry in records.entries) {
      if (TotpLegacySyncRecord.matches(entry.value)) {
        _legacyRemoteIds.add(entry.key);
      }
      final account = await _decryptRecord(entry.value);
      if (account['id'] != entry.key) {
        throw const FormatException('Sync record ID does not match');
      }
    }
  }

  @override
  String get toolId => _toolId;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    final session = _session();
    final accounts = await _vault.load(session.key);
    // Marking a legacy copy as locally newer pushes it back encrypted, which
    // also replaces the clear-text secret still stored on the server.
    for (final account in accounts) {
      if (account.deleted || !_legacyRemoteIds.contains(account.id)) continue;
      account.updatedAt = DateTime.now();
      await _vault.save(account, session.key);
    }
    return accounts
        .map(
          (account) => {
            'id': account.id,
            'updatedAt': account.updatedAt.millisecondsSinceEpoch,
            'deleted': account.deleted,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final session = _session();
    final account = (await _vault.load(session.key, id: id)).firstOrNull;
    if (account == null) return null;
    final password = await _requiredPassword();
    return {
      'version': 2,
      'payload': await TotpCrypto.encrypt(
        jsonEncode(account.toJson()),
        password,
      ),
    };
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final map = await _decryptRecord(data);
    if (map['id'] != id) {
      throw const FormatException('Sync record ID does not match');
    }
    final account = TotpAccount.fromMap(map)
      ..updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAt)
      ..deleted = deleted;
    final session = _session();
    await _vault.save(account, session.key);
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    if (!wasDeleted) return;
    _session();
    await _vault.delete(id);
  }
}

/// Records written before versioned payloads: a plain account map whose
/// `secret` is clear text or, with `encrypted`, sealed with the password.
abstract final class TotpLegacySyncRecord {
  static bool matches(Map<String, dynamic> data) =>
      data['version'] == null &&
      data['payload'] == null &&
      data['id'] is String &&
      data['id'] != TotpCrypto.syncCheckRecordId &&
      data['secret'] is String;

  static Future<Map<String, dynamic>> decode(
    Map<String, dynamic> data,
    String password,
  ) async {
    final map = Map<String, dynamic>.from(data);
    if (map['encrypted'] == true) {
      try {
        map['secret'] = await TotpCrypto.decrypt(
          map['secret'] as String,
          password,
        );
      } on SecretBoxAuthenticationError {
        throw const SyncPasswordMismatchException();
      }
    }
    map.remove('encrypted');
    return map;
  }
}

class TotpSyncWorkflow extends TotpSyncDelegate
    implements SyncWorkflowDelegate {
  TotpSyncWorkflow({required this.ready, required this.run});

  final bool Function() ready;
  final Future<void> Function(String baseUrl, String userId) run;

  @override
  Future<bool> isReadyToSync() async => ready();

  @override
  Future<Map<String, int>> runSyncWorkflow(
    String baseUrl,
    String userId,
  ) async {
    await run(baseUrl, userId);
    return {'pulled': 0, 'pushed': 0, 'deleted': 0};
  }
}
