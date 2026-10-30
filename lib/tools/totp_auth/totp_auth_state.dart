import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/tool_lock_controller.dart';

import 'config.dart';
import 'totp.dart';
import 'totp_account.dart';
import 'totp_backup.dart';
import 'totp_crypto.dart';
import 'totp_vault_store.dart';

class TotpAuthState extends ChangeNotifier {
  TotpAuthState() {
    ready = _init();
  }

  late final Future<void> ready;

  final _storage = const FlutterSecureStorage();
  final _vault = TotpVaultStore();
  late final ToolLockController lockController = ToolLockController(
    toolId: TotpAuthTool.config.id,
    envelopeSetting: TotpVaultStore.keyEnvelopeSetting,
  );
  static const _table = 'accounts';
  static const _schemaVersion = 3;

  final List<TotpAccount> _accounts = [];

  /// Active accounts in their stored order.
  List<TotpAccount> get accounts =>
      List.unmodifiable(_accounts.where((a) => !a.deleted));

  bool get hasAccounts => _accounts.any((a) => !a.deleted);

  String? get syncPassword =>
      ToolLockController.sessionFor(TotpAuthTool.config.id)?.password;

  /// Sync stays off until a password exists, so secrets never leave the device
  /// in plaintext.
  bool get hasSyncPassword => syncPassword != null;

  Timer? _ticker;

  Future<void> _init() async {
    await migrateDb();
    try {
      await _vault.finishCleanup();
    } catch (e) {
      errorLog('[TotpAuthState] Database cleanup pending: $e');
    }
    await lockController.initialize();
    lockController.addListener(_onLockChanged);
    if (lockController.unlocked) await _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_accounts.isNotEmpty) notifyListeners();
    });
    notifyListeners();
  }

  static Future<void> migrateDb() async {
    final toolDb = await DatabaseService.instance.getToolDatabase(
      TotpAuthTool.config.id,
    );
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

  static Future<void> _adoptLegacyTable(
    ToolDatabaseExecutor db,
    String table,
  ) async {
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

  static Future<void> _addMissingColumns(
    ToolDatabaseExecutor db,
    String table,
  ) async {
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

  Future<void> reloadAfterDatabaseRestore() async {
    await ready;
    lockController.lock();
    await migrateDb();
    try {
      await _vault.finishCleanup();
    } catch (e) {
      errorLog('[TotpAuthState] Database cleanup pending: $e');
    }
    await lockController.initialize();
    if (lockController.unlocked) await _load();
  }

  Future<void> _load() async {
    final session = ToolLockController.sessionFor(TotpAuthTool.config.id);
    if (session == null) return;
    final accounts = await _vault.load(session.key);
    if (!identical(
      ToolLockController.sessionFor(TotpAuthTool.config.id),
      session,
    )) {
      return;
    }
    _accounts
      ..clear()
      ..addAll(accounts);
    notifyListeners();
  }

  void _onLockChanged() {
    if (!lockController.unlocked) _accounts.clear();
    notifyListeners();
  }

  Future<void> setupVault(String password) async {
    final generation = lockController.generation;
    await _vault.finishCleanup();
    final previous = await _storage.read(key: TotpCrypto.syncPasswordKey);
    if (generation != lockController.generation) return;
    if (previous != null && previous.isNotEmpty && previous != password) {
      await lockController.recordFailure();
      throw ExistingToolPasswordMismatch();
    }
    await lockController.setup(password, _vault.migrateLegacy);
    await _storage.delete(key: TotpCrypto.syncPasswordKey);
    await _load();
  }

  Future<bool> unlockVault(String password) async {
    final generation = lockController.generation;
    await _vault.finishCleanup();
    if (generation != lockController.generation) return false;
    final success = await lockController.unlock(password);
    if (success) {
      await _storage.delete(key: TotpCrypto.syncPasswordKey);
      await _load();
    }
    return success;
  }

  Future<bool> unlockBiometric() async {
    final generation = lockController.generation;
    await _vault.finishCleanup();
    if (generation != lockController.generation) return false;
    final success = await lockController.unlockBiometric();
    if (success) await _load();
    return success;
  }

  Future<void> unlockAutomatically() async {
    if (!lockController.automatic || !lockController.configured) return;
    final generation = lockController.generation;
    await _vault.finishCleanup();
    if (generation != lockController.generation) return;
    if (await lockController.unlockAutomatically()) await _load();
  }

  Future<void> resetVault() async {
    await lockController.reset(() async {
      await _vault.reset();
      await _storage.delete(key: TotpCrypto.syncPasswordKey);
    });
    _accounts.clear();
  }

  ToolLockSession _session() {
    final session = ToolLockController.sessionFor(TotpAuthTool.config.id);
    if (session == null) throw StateError('Vault is locked');
    return session;
  }

  int _nextSortOrder() {
    if (_accounts.isEmpty) return 0;
    return _accounts.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b) +
        1;
  }

  Future<void> addAccount(TotpAccount account) async {
    final session = _session();
    account.sortOrder = account.sortOrder == 0
        ? _nextSortOrder()
        : account.sortOrder;
    await _vault.save(account, session.key);
    if (!identical(
      ToolLockController.sessionFor(TotpAuthTool.config.id),
      session,
    )) {
      return;
    }
    _accounts.add(account);
    notifyListeners();
  }

  /// Adds imported accounts, skipping ones already present. Returns the number
  /// of accounts that were actually stored.
  Future<int> importAccounts(List<TotpAccount> incoming) async {
    final session = _session();
    final known = _accounts.where((a) => !a.deleted).toList();
    var sortOrder = _nextSortOrder();
    var added = 0;
    for (final account in incoming) {
      if (known.any(account.sameIdentity)) continue;
      final stored = account.copy()
        ..sortOrder = sortOrder++
        ..updatedAt = DateTime.now();
      await _vault.save(stored, session.key);
      if (!identical(
        ToolLockController.sessionFor(TotpAuthTool.config.id),
        session,
      )) {
        return added;
      }
      _accounts.add(stored);
      known.add(stored);
      added++;
    }
    if (added > 0) notifyListeners();
    return added;
  }

  Future<void> updateAccount(TotpAccount account) async {
    final session = _session();
    account.updatedAt = DateTime.now();
    await _vault.save(account, session.key);
    if (!identical(
      ToolLockController.sessionFor(TotpAuthTool.config.id),
      session,
    )) {
      return;
    }
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) _accounts[idx] = account;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    final session = _session();
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final account = _accounts[idx]
      ..deleted = true
      ..updatedAt = DateTime.now();
    await _vault.save(account, session.key);
    if (!identical(
      ToolLockController.sessionFor(TotpAuthTool.config.id),
      session,
    )) {
      return;
    }
    notifyListeners();
  }

  Future<void> purgeDeleted() async {
    _session();
    for (final account in _accounts.where((a) => a.deleted)) {
      await _vault.delete(account.id);
    }
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

  Future<String> buildExport(TotpExportFormat format, {String? password}) {
    return TotpBackup.build(accounts, format, password: password);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    lockController.removeListener(_onLockChanged);
    lockController.lock();
    lockController.dispose();
    super.dispose();
  }
}
