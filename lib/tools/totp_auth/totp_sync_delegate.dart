import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'config.dart';
import 'totp_account.dart';
import 'totp_crypto.dart';

class TotpSyncDelegate with DefaultSyncDelegate implements SyncDelegate {
  static const _table = 'accounts';
  static String get _toolId => TotpAuthTool.config.id;

  final _storage = const FlutterSecureStorage();
  String? _password;
  bool _passwordLoaded = false;

  Future<ToolDatabase> _db() {
    return DatabaseService.instance.getToolDatabase(_toolId);
  }

  Future<String?> _syncPassword() async {
    if (!_passwordLoaded) {
      _password = await _storage.read(key: TotpCrypto.syncPasswordKey);
      _passwordLoaded = true;
    }
    return _password;
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
    final data = account.toJson();
    final password = await _syncPassword();
    if (password != null && password.isNotEmpty) {
      data['secret'] = await TotpCrypto.encrypt(account.secret, password);
      data['encrypted'] = true;
    }
    return data;
  }

  @override
  Future<void> savePulledRecord({
    required String id,
    required Map<String, dynamic> data,
    required int updatedAt,
    required bool deleted,
  }) async {
    final map = Map<String, dynamic>.from(data);
    if (map['encrypted'] == true) {
      final password = await _syncPassword();
      if (password == null || password.isEmpty) {
        throw StateError(
          'Cannot decrypt synced TOTP secrets without the sync password.',
        );
      }
      try {
        map['secret'] = await TotpCrypto.decrypt(
          map['secret'] as String,
          password,
        );
      } catch (e) {
        errorLog('[TotpSyncDelegate] Failed to decrypt pulled secret: $e');
        rethrow;
      }
      map['encrypted'] = false;
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
    // Soft deletes stay in the table until the next sync pass.
  }
}
