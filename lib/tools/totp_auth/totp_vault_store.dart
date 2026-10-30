import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/tool_vault_crypto.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'totp_account.dart';

class TotpVaultStore {
  static const String _table = 'vault_accounts';
  static const String keyEnvelopeSetting = 'vault_key_envelope';
  static const String _cleanupSetting = 'vault_cleanup_pending';

  Future<ToolDatabase> _database() async {
    final db = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${db.nameTable(_table)} (
        id TEXT PRIMARY KEY,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    return db;
  }

  String _context(String id) => '${TotpAuthTool.config.id}/account/$id';

  Future<void> save(TotpAccount account, SecretKey key) async {
    final payload = await ToolVaultCrypto.encrypt(
      jsonEncode(account.toJson()),
      key,
      context: _context(account.id),
    );
    final db = await _database();
    await db.insert(_table, {
      'id': account.id,
      'updated_at': account.updatedAt.millisecondsSinceEpoch,
      'deleted': account.deleted ? 1 : 0,
      'payload': payload,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TotpAccount>> load(SecretKey key, {String? id}) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      where: id == null ? null : 'id = ?',
      whereArgs: id == null ? null : [id],
    );
    final accounts = <TotpAccount>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final clear = await ToolVaultCrypto.decrypt(
        row['payload'] as String,
        key,
        context: _context(id),
      );
      final account = TotpAccount.fromMap(
        jsonDecode(clear) as Map<String, dynamic>,
      );
      if (account.id != id ||
          account.updatedAt.millisecondsSinceEpoch != row['updated_at'] ||
          (account.deleted ? 1 : 0) != row['deleted']) {
        throw const FormatException('Vault record metadata mismatch');
      }
      accounts.add(account);
    }
    accounts.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
    });
    return accounts;
  }

  Future<void> delete(String id) async {
    final db = await _database();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reset() async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.enableSecureDelete();
      await txn.delete(_table);
      final oldTable = txn.nameTable('accounts');
      final old = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [oldTable],
      );
      if (old.isNotEmpty) await txn.delete('accounts');
      if (await _hasLegacyTable(txn)) await txn.execute('DELETE FROM accounts');
      await txn.executor.delete(
        'tool_settings',
        where: 'tool_id = ? AND key = ?',
        whereArgs: [TotpAuthTool.config.id, keyEnvelopeSetting],
      );
      await txn.executor.insert('tool_settings', {
        'tool_id': TotpAuthTool.config.id,
        'key': _cleanupSetting,
        'value': 'true',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    try {
      await finishCleanup();
    } on ToolVaultCleanupPending {
      // The next setup retries after other readers release the database.
    }
  }

  Future<bool> _hasLegacyTable(ToolDatabaseExecutor txn) async {
    final columns = await txn.rawQuery('PRAGMA table_info(accounts)');
    final names = columns.map((row) => row['name'] as String).toSet();
    const expected = {
      'id',
      'issuer',
      'account_name',
      'secret',
      'algorithm',
      'digits',
      'period',
      'created_at',
      'updated_at',
      'deleted',
    };
    return names.length == expected.length && names.containsAll(expected);
  }

  Future<void> migrateLegacy(SecretKey key, String wrappedKey) async {
    final db = await _database();
    await db.transaction((txn) async {
      await txn.enableSecureDelete();
      final oldTable = txn.nameTable('accounts');
      final existing = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [oldTable],
      );
      if (existing.isNotEmpty) {
        final rows = await txn.query('accounts');
        for (final row in rows) {
          final account = TotpAccount.fromMap(Map<String, dynamic>.from(row));
          final payload = await ToolVaultCrypto.encrypt(
            jsonEncode(account.toJson()),
            key,
            context: _context(account.id),
          );
          await txn.insert(_table, {
            'id': account.id,
            'updated_at': account.updatedAt.millisecondsSinceEpoch,
            'deleted': account.deleted ? 1 : 0,
            'payload': payload,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
        }
        await txn.execute('DROP TABLE $oldTable');
      }
      if (await _hasLegacyTable(txn)) {
        final legacyRows = existing.isEmpty
            ? await txn.rawQuery('SELECT * FROM accounts')
            : const <Map<String, Object?>>[];
        for (final row in legacyRows) {
          final account = TotpAccount.fromMap(Map<String, dynamic>.from(row));
          final alreadyCopied = await txn.query(
            _table,
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [account.id],
            limit: 1,
          );
          if (alreadyCopied.isNotEmpty) continue;
          final payload = await ToolVaultCrypto.encrypt(
            jsonEncode(account.toJson()),
            key,
            context: _context(account.id),
          );
          await txn.insert(_table, {
            'id': account.id,
            'updated_at': account.updatedAt.millisecondsSinceEpoch,
            'deleted': account.deleted ? 1 : 0,
            'payload': payload,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
        }
        await txn.execute('DROP TABLE accounts');
      }
      await txn.executor.insert('tool_settings', {
        'tool_id': TotpAuthTool.config.id,
        'key': keyEnvelopeSetting,
        'value': wrappedKey,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      await txn.executor.insert('tool_settings', {
        'tool_id': TotpAuthTool.config.id,
        'key': _cleanupSetting,
        'value': 'true',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await finishCleanup();
  }

  Future<void> finishCleanup() async {
    final service = DatabaseService.instance;
    if (await service.getSetting(TotpAuthTool.config.id, _cleanupSetting) !=
        'true') {
      return;
    }
    final db = await service.database;
    final result = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    if (result.isNotEmpty && (result.first['busy'] as num? ?? 0) != 0) {
      throw ToolVaultCleanupPending();
    }
    await service.deleteSetting(TotpAuthTool.config.id, _cleanupSetting);
  }
}
