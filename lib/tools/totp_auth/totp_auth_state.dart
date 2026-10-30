import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'totp.dart';
import 'totp_account.dart';
import 'totp_backup.dart';
import 'totp_crypto.dart';

class TotpAuthState extends ChangeNotifier {
  TotpAuthState() {
    _init();
  }

  final _storage = const FlutterSecureStorage();
  static const _table = 'accounts';
  static const _schemaVersion = 3;

  final List<TotpAccount> _accounts = [];

  /// Active accounts in their stored order.
  List<TotpAccount> get accounts =>
      List.unmodifiable(_accounts.where((a) => !a.deleted));

  bool get hasAccounts => _accounts.any((a) => !a.deleted);

  String? _syncPassword;
  String? get syncPassword => _syncPassword;

  /// Sync stays off until a password exists, so secrets never leave the device
  /// in plaintext.
  bool get hasSyncPassword =>
      _syncPassword != null && _syncPassword!.isNotEmpty;

  Timer? _ticker;

  Future<void> _init() async {
    await _migrateDb();
    await _load();
    _syncPassword = await _storage.read(key: TotpCrypto.syncPasswordKey);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_accounts.isNotEmpty) notifyListeners();
    });
    notifyListeners();
  }

  Future<ToolDatabase> _db() {
    return DatabaseService.instance.getToolDatabase(TotpAuthTool.config.id);
  }

  Future<void> _migrateDb() async {
    final toolDb = await _db();
    await toolDb.migrate(
      currentVersion: _schemaVersion,
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
            type TEXT NOT NULL DEFAULT 'totp',
            counter INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // Version 1 created an unprefixed table; preserve any legacy rows.
        if (oldV < 2) await _adoptLegacyTable(db, table);
        await _addMissingColumns(db, table);
      },
    );
  }

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

  Future<void> _addMissingColumns(ToolDatabaseExecutor db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final existing = info.map((row) => row['name'] as String).toSet();
    Future<void> add(String column, String definition) async {
      if (existing.contains(column)) return;
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }

    await add('type', "TEXT NOT NULL DEFAULT 'totp'");
    await add('counter', 'INTEGER NOT NULL DEFAULT 0');
    await add('sort_order', 'INTEGER NOT NULL DEFAULT 0');
  }

  /// Reloads accounts from the database, e.g. after a cloud sync pull.
  Future<void> reload() => _load();

  Future<void> _load() async {
    final toolDb = await _db();
    final rows = await toolDb.query(
      _table,
      orderBy: 'sort_order ASC, created_at ASC',
    );
    _accounts
      ..clear()
      ..addAll(
        rows.map((r) => TotpAccount.fromMap(Map<String, dynamic>.from(r))),
      );
    notifyListeners();
  }

  int _nextSortOrder() {
    if (_accounts.isEmpty) return 0;
    return _accounts.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b) +
        1;
  }

  Future<void> addAccount(TotpAccount account) async {
    account.sortOrder = account.sortOrder == 0
        ? _nextSortOrder()
        : account.sortOrder;
    final toolDb = await _db();
    await toolDb.insert(
      _table,
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _accounts.add(account);
    notifyListeners();
  }

  /// Adds imported accounts, skipping ones already present. Returns the number
  /// of accounts that were actually stored.
  Future<int> importAccounts(List<TotpAccount> incoming) async {
    final known = _accounts.where((a) => !a.deleted).toList();
    var sortOrder = _nextSortOrder();
    var added = 0;
    final toolDb = await _db();
    for (final account in incoming) {
      if (known.any(account.sameIdentity)) continue;
      final stored = account.copy()
        ..sortOrder = sortOrder++
        ..updatedAt = DateTime.now();
      await toolDb.insert(
        _table,
        stored.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _accounts.add(stored);
      known.add(stored);
      added++;
    }
    if (added > 0) notifyListeners();
    return added;
  }

  Future<void> updateAccount(TotpAccount account) async {
    account.updatedAt = DateTime.now();
    final toolDb = await _db();
    await toolDb.update(
      _table,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) _accounts[idx] = account;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    final toolDb = await _db();
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final account = _accounts[idx]
      ..deleted = true
      ..updatedAt = DateTime.now();
    await toolDb.update(
      _table,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }

  Future<void> purgeDeleted() async {
    final toolDb = await _db();
    await toolDb.delete(_table, where: 'deleted = ?', whereArgs: [1]);
    _accounts.removeWhere((a) => a.deleted);
    notifyListeners();
  }

  TotpAccount? findById(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  List<TotpAccount> search(String query) {
    return accounts.where((a) => a.matches(query)).toList();
  }

  String codeFor(TotpAccount account, {DateTime? now}) {
    try {
      final secret = Totp.decodeBase32(account.secret);
      final code = account.type == TotpType.hotp
          ? Totp.generateCounter(
              secret: secret,
              counter: account.counter,
              digits: account.digits,
              algorithm: account.algorithm,
            )
          : Totp.generate(
              secret: secret,
              timeSeconds:
                  (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
              period: account.period,
              digits: account.digits,
              algorithm: account.algorithm,
            );
      return Totp.formatCode(code, account.digits);
    } catch (e) {
      errorLog('[TotpAuthState] Failed to generate code: $e');
      return '-' * account.digits;
    }
  }

  String currentCode(TotpAccount account) => codeFor(account);

  int secondsRemaining(TotpAccount account) {
    if (account.type == TotpType.hotp) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = account.period - (now % account.period);
    return remaining <= 0 ? account.period : remaining;
  }

  /// Advances the HOTP counter and returns the newly generated code.
  Future<String> advanceCounter(TotpAccount account) async {
    account.counter += 1;
    await updateAccount(account);
    return codeFor(account);
  }

  Future<void> setSyncPassword(String? password) async {
    final changed = password != _syncPassword;
    _syncPassword = password;
    if (password == null || password.isEmpty) {
      await _storage.delete(key: TotpCrypto.syncPasswordKey);
    } else {
      await _storage.write(key: TotpCrypto.syncPasswordKey, value: password);
      // Remote copies are encrypted with the previous password, so every
      // account is re-pushed under the new one on the next sync.
      if (changed) await _touchAll();
    }
    notifyListeners();
  }

  Future<void> _touchAll() async {
    final toolDb = await _db();
    final now = DateTime.now();
    for (final account in _accounts) {
      account.updatedAt = now;
      await toolDb.update(
        _table,
        account.toMap(),
        where: 'id = ?',
        whereArgs: [account.id],
      );
    }
  }

  Future<String> buildExport(TotpExportFormat format, {String? password}) {
    return TotpBackup.build(accounts, format, password: password);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
