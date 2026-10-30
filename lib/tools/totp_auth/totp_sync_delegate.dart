import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'totp_account.dart';
import 'totp_auth_state.dart';
import 'totp_crypto.dart';

class TotpSyncDelegate
    with DefaultSyncDelegate
    implements SyncDelegate, SyncPreflightDelegate {
  static const _table = 'accounts';
  static String get _toolId => TotpAuthTool.config.id;

  final _storage = const FlutterSecureStorage();
  String? _password;
  bool _passwordLoaded = false;

  Future<ToolDatabase> _db() async {
    await TotpAuthState.migrateDb();
    return DatabaseService.instance.getToolDatabase(_toolId);
  }

  Future<String?> _syncPassword() async {
    if (!_passwordLoaded) {
      _password = await _storage.read(key: TotpCrypto.syncPasswordKey);
      _passwordLoaded = true;
    }
    return _password;
  }

  /// Re-reads the stored password so a password set after startup applies to
  /// the next run.
  @override
  Future<bool> isReadyToSync() async {
    _password = await _storage.read(key: TotpCrypto.syncPasswordKey);
    _passwordLoaded = true;
    return _password != null && _password!.isNotEmpty;
  }

  Future<String> _requiredPassword() async {
    final password = await _syncPassword();
    if (password == null || password.isEmpty) {
      throw StateError('A sync password is required');
    }
    return password;
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
    final db = await _db();
    final rows = await db.query(
      _table,
      columns: ['id', 'updated_at', 'deleted'],
    );
    return rows
        .map(
          (row) => {
            'id': row['id'] as String,
            'updatedAt': (row['updated_at'] as num?)?.toInt() ?? 0,
            'deleted': (row['deleted'] as num?)?.toInt() == 1,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final db = await _db();
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final account = TotpAccount.fromMap(Map<String, dynamic>.from(rows.first));
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
    final db = await _db();
    await db.insert(
      _table,
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    if (!wasDeleted) return;
    final db = await _db();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
