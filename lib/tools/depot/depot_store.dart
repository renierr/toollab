import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/depot_holding.dart';
import 'models/depot_portfolio.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';

/// Local mirror of the Parqet data. Parqet is the source of truth, so a sync
/// replaces everything instead of merging.
class DepotStore {
  DepotStore._();
  static final DepotStore instance = DepotStore._();

  /// Summary and chart scope for all portfolios combined.
  static const String allScope = '_all';

  static const _portfolios = 'portfolios';
  static const _holdings = 'holdings';
  static const _transactions = 'transactions';
  static const _summaries = 'summaries';
  static const _chartPoints = 'chart_points';

  static const _clientIdKey = 'parqet_client_id';
  static const _lastSyncKey = 'parqet_last_sync_at';

  String get _toolId => DepotTool.config.id;

  Future<ToolDatabase>? _db;

  Future<ToolDatabase> _getDb() => _db ??= _open();

  Future<ToolDatabase> _open() async {
    final db = await DatabaseService.instance.getToolDatabase(_toolId);
    try {
      await db.migrate(
        currentVersion: 1,
        onMigrate: (txn, oldVersion, newVersion) async {
          if (oldVersion < 1) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_portfolios)} (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                currency TEXT NOT NULL,
                created_at INTEGER,
                brokers TEXT NOT NULL DEFAULT ''
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_holdings)} (
                id TEXT NOT NULL,
                portfolio_id TEXT NOT NULL,
                name TEXT NOT NULL,
                asset_type TEXT NOT NULL,
                isin TEXT,
                symbol TEXT,
                logo TEXT,
                shares REAL NOT NULL,
                purchase_price REAL NOT NULL,
                purchase_value REAL NOT NULL,
                current_price REAL NOT NULL,
                current_value REAL NOT NULL,
                is_sold INTEGER NOT NULL,
                unrealized_gain REAL NOT NULL,
                unrealized_return REAL NOT NULL,
                realized_gain REAL NOT NULL,
                dividends REAL NOT NULL,
                fees REAL NOT NULL,
                taxes REAL NOT NULL,
                xirr REAL,
                ttwror REAL,
                earliest_activity INTEGER,
                quote_at INTEGER,
                PRIMARY KEY (portfolio_id, id)
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_transactions)} (
                id TEXT NOT NULL,
                portfolio_id TEXT NOT NULL,
                holding_id TEXT NOT NULL,
                type TEXT NOT NULL,
                asset_type TEXT NOT NULL,
                datetime INTEGER NOT NULL,
                shares REAL NOT NULL,
                price REAL NOT NULL,
                amount REAL NOT NULL,
                amount_net REAL NOT NULL,
                tax REAL NOT NULL,
                fee REAL NOT NULL,
                currency TEXT NOT NULL,
                broker TEXT,
                realized_gain REAL,
                PRIMARY KEY (portfolio_id, id)
              )
            ''');
            await txn.execute(
              'CREATE INDEX ${txn.nameTable('transactions_datetime')} '
              'ON ${txn.nameTable(_transactions)} (datetime)',
            );
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_summaries)} (
                scope TEXT PRIMARY KEY,
                currency TEXT NOT NULL,
                value_start REAL NOT NULL,
                value_end REAL NOT NULL,
                xirr REAL,
                ttwror REAL,
                unrealized_gain REAL NOT NULL,
                unrealized_return REAL NOT NULL,
                realized_gain REAL NOT NULL,
                dividends REAL NOT NULL,
                fees REAL NOT NULL,
                taxes REAL NOT NULL,
                synced_at INTEGER NOT NULL
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_chartPoints)} (
                scope TEXT NOT NULL,
                date INTEGER NOT NULL,
                value REAL NOT NULL,
                capital REAL NOT NULL,
                drawdown REAL NOT NULL,
                PRIMARY KEY (scope, date)
              )
            ''');
          }
        },
      );
    } catch (e) {
      errorLog('[DepotStore] Migration failed: $e');
      _db = null;
      rethrow;
    }
    return db;
  }

  Future<String?> clientId() =>
      DatabaseService.instance.getSetting(_toolId, _clientIdKey);

  Future<void> setClientId(String clientId) =>
      DatabaseService.instance.setSetting(_toolId, _clientIdKey, clientId);

  Future<DateTime?> lastSyncAt() async {
    final stored = await DatabaseService.instance.getSetting(
      _toolId,
      _lastSyncKey,
    );
    final ms = int.tryParse(stored ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<List<DepotPortfolio>> portfolios() async {
    final db = await _getDb();
    final rows = await db.query(_portfolios, orderBy: 'name COLLATE NOCASE');
    return rows.map(DepotPortfolio.fromMap).toList();
  }

  /// Every holding, or only those of [portfolioId].
  Future<List<DepotHolding>> holdings({String? portfolioId}) async {
    final db = await _getDb();
    final rows = await db.query(
      _holdings,
      where: portfolioId == null ? null : 'portfolio_id = ?',
      whereArgs: portfolioId == null ? null : [portfolioId],
      orderBy: 'current_value DESC',
    );
    return rows.map(DepotHolding.fromMap).toList();
  }

  Future<List<DepotTransaction>> transactions({String? portfolioId}) async {
    final db = await _getDb();
    final t = db.nameTable(_transactions);
    final h = db.nameTable(_holdings);
    final rows = await db.rawQuery(
      'SELECT t.*, h.name AS holding_name FROM $t t '
      'LEFT JOIN $h h ON h.portfolio_id = t.portfolio_id AND h.id = t.holding_id '
      '${portfolioId == null ? '' : 'WHERE t.portfolio_id = ? '}'
      'ORDER BY t.datetime DESC',
      portfolioId == null ? null : [portfolioId],
    );
    return rows.map(DepotTransaction.fromMap).toList();
  }

  Future<DepotSummary?> summary(String scope) async {
    final db = await _getDb();
    final rows = await db.query(
      _summaries,
      where: 'scope = ?',
      whereArgs: [scope],
      limit: 1,
    );
    return rows.isEmpty ? null : DepotSummary.fromMap(rows.first);
  }

  Future<List<DepotChartPoint>> chart(String scope) async {
    final db = await _getDb();
    final rows = await db.query(
      _chartPoints,
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'date ASC',
    );
    return rows.map(DepotChartPoint.fromMap).toList();
  }

  /// Swaps the whole mirror in one transaction, so a reader never sees half
  /// of a sync.
  Future<void> replaceAll({
    required List<DepotPortfolio> portfolios,
    required List<DepotHolding> holdings,
    required List<DepotTransaction> transactions,
    required List<DepotSummary> summaries,
    required Map<String, List<DepotChartPoint>> charts,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      for (final table in [
        _portfolios,
        _holdings,
        _transactions,
        _summaries,
        _chartPoints,
      ]) {
        await txn.delete(table);
      }
      final batch = txn.batch();
      for (final p in portfolios) {
        batch.insert(_portfolios, p.toMap());
      }
      for (final h in holdings) {
        batch.insert(
          _holdings,
          h.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in transactions) {
        batch.insert(
          _transactions,
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final s in summaries) {
        batch.insert(_summaries, s.toMap());
      }
      for (final entry in charts.entries) {
        for (final point in entry.value) {
          batch.insert(
            _chartPoints,
            point.toMap(entry.key),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    });
    await DatabaseService.instance.setSetting(
      _toolId,
      _lastSyncKey,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> clear() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      for (final table in [
        _portfolios,
        _holdings,
        _transactions,
        _summaries,
        _chartPoints,
      ]) {
        await txn.delete(table);
      }
    });
    await DatabaseService.instance.deleteSetting(_toolId, _lastSyncKey);
  }
}
