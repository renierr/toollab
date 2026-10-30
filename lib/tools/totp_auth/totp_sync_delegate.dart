import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';

import 'config.dart';
import 'totp_account.dart';
import 'totp_crypto.dart';
import 'totp_vault_store.dart';

class TotpSyncDelegate
    with DefaultSyncDelegate
    implements SyncDelegate, SyncPreflightDelegate, SyncSessionGuard {
  static String get _toolId => TotpAuthTool.config.id;

  final _vault = TotpVaultStore();
  ToolLockSession? _runSession;

  @override
  void beginSyncSession() {
    _runSession = ToolLockController.sessionFor(_toolId);
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
    return ToolLockController.sessionFor(_toolId) != null;
  }

  Future<String> _requiredPassword() async {
    return _session().password;
  }

  Future<Map<String, dynamic>> _decryptRecord(Map<String, dynamic> data) async {
    if (data['version'] != 2 || data['payload'] is! String) {
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
      return decoded;
    } on SecretBoxAuthenticationError {
      throw const SyncPasswordMismatchException();
    }
  }

  @override
  Future<void> verifyRemotePayloads(
    Map<String, Map<String, dynamic>> records,
  ) async {
    for (final entry in records.entries) {
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
