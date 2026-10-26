import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';

import 'totp.dart';
import 'totp_account.dart';
import 'totp_crypto.dart';
import 'config.dart';

class TotpAuthState extends ChangeNotifier with DefaultSyncDelegate {
  TotpAuthState() {
    _init();
  }

  final _storage = const FlutterSecureStorage();
  static const _pwKey = 'totp_sync_password';
  static const _table = 'accounts';

  final List<TotpAccount> _accounts = [];
  List<TotpAccount> get accounts => List.unmodifiable(_accounts);

  String? _syncPassword;
  String? get syncPassword => _syncPassword;

  Timer? _ticker;
  String? _error;
  String? get error => _error;

  Future<void> _init() async {
    await _migrateDb();
    await _load();
    _syncPassword = await _storage.read(key: _pwKey);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    notifyListeners();
  }

  Future<void> _migrateDb() async {
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    await toolDb.migrate(
      currentVersion: 2,
      onMigrate: (db, oldV, newV) async {
        final table = db.nameTable(_table);
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $table (
            id TEXT PRIMARY KEY,
            issuer TEXT NOT NULL,
            account_name TEXT NOT NULL,
            secret TEXT NOT NULL,
            algorithm TEXT NOT NULL,
            digits INTEGER NOT NULL,
            period INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        if (oldV < 2) await _adoptLegacyTable(db, table);
      },
    );
  }

  // Version 1 created an unprefixed table; preserve any legacy rows.
  Future<void> _adoptLegacyTable(ToolDatabaseExecutor db, String table) async {
    final legacy = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [_table],
    );
    if (legacy.isEmpty) return;
    const columns =
        'id, issuer, account_name, secret, algorithm, digits, period, '
        'created_at, updated_at, deleted';
    await db.rawInsert(
      'INSERT OR IGNORE INTO $table ($columns) '
      'SELECT $columns FROM $_table',
    );
  }

  Future<void> _load() async {
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    final rows = await toolDb.query('accounts');
    _accounts
      ..clear()
      ..addAll(
        rows.map((r) => TotpAccount.fromMap(Map<String, dynamic>.from(r))),
      );
    notifyListeners();
  }

  Future<void> addAccount(TotpAccount acc) async {
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    await toolDb.insert(
      'accounts',
      acc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _accounts.add(acc);
    notifyListeners();
  }

  Future<void> updateAccount(TotpAccount acc) async {
    acc.updatedAt = DateTime.now();
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    await toolDb.update(
      'accounts',
      acc.toMap(),
      where: 'id = ?',
      whereArgs: [acc.id],
    );
    final idx = _accounts.indexWhere((a) => a.id == acc.id);
    if (idx >= 0) _accounts[idx] = acc;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      _accounts[idx].deleted = true;
      _accounts[idx].updatedAt = DateTime.now();
      await toolDb.update(
        'accounts',
        _accounts[idx].toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    notifyListeners();
  }

  Future<void> purgeDeleted() async {
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    await toolDb.delete('accounts', where: 'deleted = ?', whereArgs: [1]);
    _accounts.removeWhere((a) => a.deleted);
    notifyListeners();
  }

  TotpAccount? findById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  String currentCode(TotpAccount a) {
    try {
      final secret = Totp.decodeBase32(a.secret);
      final code = Totp.generate(
        secret: secret,
        timeSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        period: a.period,
        digits: a.digits,
        algorithm: a.algorithm,
      );
      return Totp.formatCode(code, a.digits);
    } catch (_) {
      return '------';
    }
  }

  int secondsRemaining(TotpAccount a) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return a.period - (now % a.period);
  }

  Future<void> setSyncPassword(String? password) async {
    _syncPassword = password;
    if (password == null || password.isEmpty) {
      await _storage.delete(key: _pwKey);
    } else {
      await _storage.write(key: _pwKey, value: password);
    }
    notifyListeners();
  }

  // --- SyncDelegate (DefaultSyncDelegate) ---
  @override
  String get toolId => TotpAuthTool.config.id;

  @override
  Future<List<Map<String, dynamic>>> getLocalSyncRecords() async {
    return _accounts
        .map(
          (a) => {
            'id': a.id,
            'updatedAt': a.updatedAt.millisecondsSinceEpoch,
            'deleted': a.deleted,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getLocalRecordData(String id) async {
    final a = findById(id);
    if (a == null) return null;
    final data = a.toMap();
    if (_syncPassword != null && _syncPassword!.isNotEmpty) {
      data['secret'] = await TotpCrypto.encrypt(a.secret, _syncPassword!);
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
    Map<String, dynamic> d = Map<String, dynamic>.from(data);
    if (d['encrypted'] == true &&
        _syncPassword != null &&
        _syncPassword!.isNotEmpty) {
      d['secret'] = await TotpCrypto.decrypt(
        d['secret'] as String,
        _syncPassword!,
      );
      d['encrypted'] = false;
    }
    final acc = TotpAccount.fromMap(d);
    acc.updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    acc.deleted = deleted;
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
    final existing = _accounts.indexWhere((a) => a.id == id);
    if (existing >= 0) {
      await toolDb.update(
        'accounts',
        acc.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      _accounts[existing] = acc;
    } else {
      await toolDb.insert(
        'accounts',
        acc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _accounts.add(acc);
    }
    notifyListeners();
  }

  @override
  Future<void> finalizeLocalSync(String id, bool wasDeleted) async {
    // no-op
  }

  // --- Export / Import ---
  Future<String> exportEncrypted(String password) async {
    final list = _accounts
        .where((a) => !a.deleted)
        .map((a) => a.toMap())
        .toList();
    final json = jsonEncode(list);
    return TotpCrypto.encrypt(json, password);
  }

  Future<void> importEncrypted(String payload, String password) async {
    final json = await TotpCrypto.decrypt(payload, password);
    final list = jsonDecode(json) as List<dynamic>;
    for (final item in list) {
      final acc = TotpAccount.fromMap(Map<String, dynamic>.from(item as Map));
      acc.updatedAt = DateTime.now();
      await addAccount(acc);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
