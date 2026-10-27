import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/depot_dividend.dart';
import 'models/depot_filters.dart';
import 'models/depot_holding.dart';
import 'models/depot_holding_logo.dart';
import 'models/depot_period.dart';
import 'models/depot_portfolio.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';

/// Local Parqet mirror, with performance cached independently per period.
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
  static const _holdingPerformance = 'holding_performance';
  static const _holdingLogos = 'holding_logos';

  static const _dividendAssets = 'dividend_assets';
  static const _dividendEvents = 'dividend_events';

  /// Parqet mirror only; the dividend cache survives a sync.
  static const _tables = [
    _portfolios,
    _holdings,
    _holdingPerformance,
    _summaries,
    _chartPoints,
  ];

  static const _clientIdKey = 'parqet_client_id';
  static const _lastSyncKey = 'parqet_last_sync_at';
  static const _activityFullSyncKey = 'parqet_activity_full_sync_at';
  static const _holdingSortKey = 'holding_sort';

  String get _toolId => DepotTool.config.id;

  Future<ToolDatabase>? _db;

  Future<ToolDatabase> _getDb() => _db ??= _open();

  Future<ToolDatabase> _open() async {
    final db = await DatabaseService.instance.getToolDatabase(_toolId);
    try {
      await db.migrate(
        currentVersion: 5,
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
          }
          if (oldVersion < 2) {
            // Only a mirror of Parqet, so the old table is dropped instead of
            // migrated, and the next sync refills it.
            await txn.execute(
              'DROP TABLE IF EXISTS ${txn.nameTable(_chartPoints)}',
            );
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_chartPoints)} (
                scope TEXT NOT NULL,
                period TEXT NOT NULL,
                date INTEGER NOT NULL,
                value REAL NOT NULL,
                capital REAL NOT NULL,
                drawdown REAL NOT NULL,
                PRIMARY KEY (scope, period, date)
              )
            ''');
          }
          if (oldVersion < 3) {
            await txn.execute(
              'DROP TABLE IF EXISTS ${txn.nameTable(_summaries)}',
            );
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_summaries)} (
                scope TEXT NOT NULL,
                period TEXT NOT NULL,
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
                synced_at INTEGER NOT NULL,
                PRIMARY KEY (scope, period)
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_holdingPerformance)} (
                portfolio_id TEXT NOT NULL,
                holding_id TEXT NOT NULL,
                period TEXT NOT NULL,
                gain REAL NOT NULL,
                return_percent REAL,
                PRIMARY KEY (portfolio_id, holding_id, period)
              )
            ''');
          }
          if (oldVersion < 4) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_dividendAssets)} (
                key TEXT PRIMARY KEY,
                symbol TEXT,
                currency TEXT NOT NULL,
                fx_currency TEXT NOT NULL,
                fx_rate REAL NOT NULL,
                next_ex_date INTEGER,
                next_pay_date INTEGER,
                fetched_at INTEGER NOT NULL
              )
            ''');
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_dividendEvents)} (
                asset_key TEXT NOT NULL,
                ex_date INTEGER NOT NULL,
                amount REAL NOT NULL,
                PRIMARY KEY (asset_key, ex_date)
              )
            ''');
          }
          if (oldVersion < 5) {
            await txn.execute('''
              CREATE TABLE ${txn.nameTable(_holdingLogos)} (
                asset_key TEXT PRIMARY KEY,
                source_url TEXT NOT NULL,
                data BLOB NOT NULL,
                fetched_at INTEGER NOT NULL
              )
            ''');
          }
          // Only migrations that rebuild performance tables invalidate sync.
          if (oldVersion < 3) {
            await txn.executor.delete(
              'tool_settings',
              where: 'tool_id = ? AND key = ?',
              whereArgs: [_toolId, _lastSyncKey],
            );
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

  /// Newest stored booking of [portfolioId], the watermark an incremental
  /// activity sync starts from.
  Future<DateTime?> newestTransactionAt(String portfolioId) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT MAX(datetime) AS newest FROM ${db.nameTable(_transactions)} '
      'WHERE portfolio_id = ?',
      [portfolioId],
    );
    final newest = rows.first['newest'] as int?;
    return newest == null ? null : DateTime.fromMillisecondsSinceEpoch(newest);
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

  Future<List<DepotHoldingLogo>> holdingLogos() async {
    final db = await _getDb();
    final rows = await db.query(_holdingLogos);
    return rows.map(DepotHoldingLogo.fromMap).toList();
  }

  Future<void> saveHoldingLogo(DepotHoldingLogo logo) async {
    final db = await _getDb();
    await db.insert(
      _holdingLogos,
      logo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  /// Keyed by [DepotHoldingPerformance.key].
  Future<Map<String, DepotHoldingPerformance>> holdingPerformance(
    DepotPeriod period, {
    String? portfolioId,
  }) async {
    final db = await _getDb();
    final rows = await db.query(
      _holdingPerformance,
      where: portfolioId == null
          ? 'period = ?'
          : 'period = ? AND portfolio_id = ?',
      whereArgs: [period.wire, ?portfolioId],
    );
    final performance = rows.map(DepotHoldingPerformance.fromMap);
    return {for (final p in performance) p.key: p};
  }

  Future<DepotSummary?> summary(DepotPeriodKey key) async {
    final db = await _getDb();
    final rows = await db.query(
      _summaries,
      where: 'scope = ? AND period = ?',
      whereArgs: [key.scope, key.period.wire],
      limit: 1,
    );
    return rows.isEmpty ? null : DepotSummary.fromMap(rows.first);
  }

  Future<DepotHoldingSort> holdingSort() async {
    final stored = await DatabaseService.instance.getSetting(
      _toolId,
      _holdingSortKey,
    );
    return DepotHoldingSort.values.firstWhere(
      (s) => s.name == stored,
      orElse: () => DepotHoldingSort.returnPercent,
    );
  }

  Future<void> setHoldingSort(DepotHoldingSort sort) =>
      DatabaseService.instance.setSetting(_toolId, _holdingSortKey, sort.name);

  Future<List<DepotChartPoint>> chart(DepotPeriodKey key) async {
    final db = await _getDb();
    final rows = await db.query(
      _chartPoints,
      where: 'scope = ? AND period = ?',
      whereArgs: [key.scope, key.period.wire],
      orderBy: 'date ASC',
    );
    return rows.map(DepotChartPoint.fromMap).toList();
  }

  /// Commits holdings and activities without discarding unrequested periods.
  Future<void> replaceAll({
    required List<DepotPortfolio> portfolios,
    required List<DepotHolding> holdings,
    required List<DepotHoldingPerformance> holdingPerformance,
    required List<DepotTransaction> transactions,
    required List<DepotSummary> summaries,
    required Map<DepotPeriodKey, List<DepotChartPoint>> charts,
    required Set<String> completeActivityPortfolios,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await _replacePortfolios(txn, portfolios);
      await txn.delete(_holdings);
      await _pruneTransactions(txn, portfolios, completeActivityPortfolios);
      final batch = txn.batch();
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
      await batch.commit(noResult: true);
      await _writePerformance(txn, summaries, charts, holdingPerformance);
    });
    await DatabaseService.instance.setSetting(
      _toolId,
      _lastSyncKey,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<void> savePerformance({
    List<DepotPortfolio>? portfolios,
    List<DepotHolding>? holdings,
    required List<DepotSummary> summaries,
    required Map<DepotPeriodKey, List<DepotChartPoint>> charts,
    required List<DepotHoldingPerformance> holdingPerformance,
  }) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      if (portfolios != null) await _replacePortfolios(txn, portfolios);
      if (holdings != null) {
        await txn.delete(_holdings);
        final batch = txn.batch();
        for (final holding in holdings) {
          batch.insert(
            _holdings,
            holding.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
      await _writePerformance(txn, summaries, charts, holdingPerformance);
    });
  }

  static Future<void> _writePerformance(
    ToolDatabaseExecutor txn,
    List<DepotSummary> summaries,
    Map<DepotPeriodKey, List<DepotChartPoint>> charts,
    List<DepotHoldingPerformance> holdingPerformance,
  ) async {
    for (final summary in summaries) {
      for (final table in [_summaries, _chartPoints]) {
        await txn.delete(
          table,
          where: 'scope = ? AND period = ?',
          whereArgs: [summary.scope, summary.period.wire],
        );
      }
      if (summary.scope != allScope) {
        await txn.delete(
          _holdingPerformance,
          where: 'portfolio_id = ? AND period = ?',
          whereArgs: [summary.scope, summary.period.wire],
        );
      }
    }
    final batch = txn.batch();
    for (final summary in summaries) {
      batch.insert(
        _summaries,
        summary.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
    // A holding listed twice must not roll back the whole sync.
    for (final performance in holdingPerformance) {
      batch.insert(
        _holdingPerformance,
        performance.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _replacePortfolios(
    ToolDatabaseExecutor txn,
    List<DepotPortfolio> portfolios,
  ) async {
    final previous = await txn.query(_portfolios, columns: ['id']);
    final ids = portfolios.map((p) => p.id).toSet();
    final changed =
        previous.length != ids.length ||
        previous.any((row) => !ids.contains(row['id']));
    await txn.delete(_portfolios);
    final batch = txn.batch();
    for (final portfolio in portfolios) {
      batch.insert(_portfolios, portfolio.toMap());
    }
    await batch.commit(noResult: true);
    for (final table in [
      _summaries,
      _chartPoints,
      _holdingPerformance,
      _holdings,
      _transactions,
    ]) {
      final column = table == _summaries || table == _chartPoints
          ? 'scope'
          : 'portfolio_id';
      final keep = [if (column == 'scope' && !changed) allScope, ...ids];
      await txn.delete(
        table,
        where: keep.isEmpty
            ? null
            : '$column NOT IN (${_placeholders(keep.length)})',
        whereArgs: keep.isEmpty ? null : keep,
      );
    }
  }

  /// Drops bookings of portfolios that no longer exist and, for the ones read
  /// to the end, everything a fresh read is about to restore.
  static Future<void> _pruneTransactions(
    ToolDatabaseExecutor txn,
    List<DepotPortfolio> portfolios,
    Set<String> complete,
  ) async {
    if (portfolios.isEmpty) {
      await txn.delete(_transactions);
      return;
    }
    final ids = [for (final p in portfolios) p.id];
    await txn.delete(
      _transactions,
      where: 'portfolio_id NOT IN (${_placeholders(ids.length)})',
      whereArgs: ids,
    );
    if (complete.isEmpty) return;
    final replaced = complete.toList();
    await txn.delete(
      _transactions,
      where: 'portfolio_id IN (${_placeholders(replaced.length)})',
      whereArgs: replaced,
    );
  }

  static String _placeholders(int count) => List.filled(count, '?').join(',');

  /// Keyed by [DepotDividendAsset.key].
  Future<Map<String, DepotDividendAsset>> dividendAssets() async {
    final db = await _getDb();
    final events = <String, List<DepotDividendEvent>>{};
    final eventRows = await db.query(_dividendEvents, orderBy: 'ex_date ASC');
    for (final row in eventRows) {
      events
          .putIfAbsent(row['asset_key'] as String, () => [])
          .add(DepotDividendEvent.fromMap(row));
    }
    final rows = await db.query(_dividendAssets);
    return {
      for (final row in rows)
        row['key'] as String: DepotDividendAsset.fromMap(
          row,
          events[row['key']] ?? const [],
        ),
    };
  }

  Future<void> saveDividendAsset(DepotDividendAsset asset) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(
        _dividendEvents,
        where: 'asset_key = ?',
        whereArgs: [asset.key],
      );
      final batch = txn.batch();
      batch.insert(
        _dividendAssets,
        asset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final event in asset.events) {
        batch.insert(
          _dividendEvents,
          event.toMap(asset.key),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> clear() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      for (final table in [
        ..._tables,
        _transactions,
        _dividendAssets,
        _dividendEvents,
        _holdingLogos,
      ]) {
        await txn.delete(table);
      }
    });
    await DatabaseService.instance.deleteSetting(_toolId, _lastSyncKey);
    await DatabaseService.instance.deleteSetting(_toolId, _activityFullSyncKey);
  }
}
