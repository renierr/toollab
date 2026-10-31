import 'dart:math';

import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'models/depot_holding.dart';
import 'models/depot_period.dart';
import 'models/depot_portfolio.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';
import 'parqet/parqet_api.dart';
import 'parqet/parqet_auth.dart';
import 'parqet/parqet_exception.dart';

class DepotParqetSync {
  DepotParqetSync._();

  static const _maxCombined = 25;
  static const _maxConcurrent = 2;
  static const _activityOverlap = Duration(days: 3);

  /// Parqet has no documented RPS budget, so request starts are spaced out.
  static const _requestGap = Duration(milliseconds: 200);
  static const _retryBase = Duration(seconds: 1);
  static const _retryMax = Duration(seconds: 30);
  static final _random = Random();
  static DateTime _nextRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Beyond this many changed holdings one portfolio-wide read is cheaper.
  static const _maxHoldingReads = 10;

  static Future<bool> isConnected() async {
    final clientId = await DepotStore.instance.clientId();
    if (clientId == null || clientId.isEmpty) return false;
    return await ParqetAuth.readTokens() != null;
  }

  static Future<ParqetApi> _api() async {
    final clientId = await DepotStore.instance.clientId();
    if (clientId == null || clientId.isEmpty) {
      throw const ParqetException(ParqetErrorKind.notConnected);
    }
    return ParqetApi(clientId: clientId);
  }

  /// Publishes the visible period before loading holdings and activities.
  /// Only an explicit [full] run rereads all periods and activity history.
  static Future<String> run({
    bool full = false,
    DepotPeriod period = DepotPeriod.today,
    Future<void> Function()? onPeriodReady,
    ParqetApi? api,
  }) async {
    final store = DepotStore.instance;
    final client = api ?? await _api();
    final portfolios = await client.portfolios();
    final knownCounts = await store.activityCounts();
    final priority = _PerformancePull(client, portfolios);
    await _runPooled(priority.jobs({period}, combined: true));
    await store.savePerformance(
      portfolios: portfolios,
      holdings: period == DepotPeriod.max ? priority.holdings : null,
      quotes: priority.quotes,
      summaries: priority.summaries,
      charts: priority.charts,
      holdingPerformance: priority.holdingPerformance,
    );
    await onPeriodReady?.call();

    final remaining = _PerformancePull(client, portfolios);
    final periods = full
        ? DepotPeriod.values.where((p) => p != period).toSet()
        : {if (period != DepotPeriod.max) DepotPeriod.max};
    // Activity counts come with Max, which decides what activities to read.
    await _runPooled(remaining.jobs(periods, combined: full));

    final counts = {...priority.activityCounts, ...remaining.activityCounts};
    final activities = _ActivityPull(client);
    await _runPooled([
      for (final portfolio in portfolios)
        ...activities.jobs(
          portfolio.id,
          full: full,
          known: knownCounts[portfolio.id],
          current: counts[portfolio.id] ?? const {},
        ),
    ]);

    final holdings = [...priority.holdings, ...remaining.holdings];
    await store.replaceAll(
      portfolios: portfolios,
      holdings: holdings,
      holdingPerformance: remaining.holdingPerformance,
      transactions: activities.transactions,
      summaries: remaining.summaries,
      charts: remaining.charts,
      completeActivityPortfolios: activities.complete,
      reloadedHoldings: activities.reloaded,
      activityCounts: {
        for (final MapEntry(:key, :value) in counts.entries)
          if (value.isNotEmpty) key: value,
      },
    );

    final detail =
        '${portfolios.length} portfolios, ${holdings.length} holdings, '
        '${activities.transactions.length} activities, '
        '${activities.reloaded.values.fold(0, (n, ids) => n + ids.length)} '
        'holdings reconciled';
    debugLog('[DepotParqetSync] $detail');
    return detail;
  }

  /// Refreshes just one period; it does not advance the activity sync timestamp.
  static Future<void> refreshPeriod({
    required DepotPeriod period,
    required List<DepotPortfolio> portfolios,
    ParqetApi? api,
  }) async {
    final pull = _PerformancePull(api ?? await _api(), portfolios);
    await _runPooled(pull.jobs({period}, combined: true));
    await DepotStore.instance.savePerformance(
      summaries: pull.summaries,
      charts: pull.charts,
      holdingPerformance: pull.holdingPerformance,
      holdings: period == DepotPeriod.max ? pull.holdings : null,
      quotes: pull.quotes,
    );
  }

  static Future<void> _runPooled(List<Future<void> Function()> jobs) async {
    debugLog(
      '[DepotParqetSync] Running ${jobs.length} jobs, '
      '$_maxConcurrent at a time',
    );
    var next = 0;
    Object? failure;
    StackTrace? failureStack;

    Future<void> worker() async {
      while (failure == null && next < jobs.length) {
        final job = jobs[next++];
        try {
          await _withRetry(job);
        } catch (e, stack) {
          errorLog('[DepotParqetSync] Stopping pool after failure: $e');
          failure ??= e;
          failureStack ??= stack;
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < _maxConcurrent && i < jobs.length; i++) worker(),
    ]);
    final error = failure;
    if (error != null) Error.throwWithStackTrace(error, failureStack!);
  }

  /// Spaced across all workers, so a sync does not start a burst of requests.
  static Future<void> _throttle() {
    final now = DateTime.now();
    final slot = _nextRequestAt.isAfter(now) ? _nextRequestAt : now;
    _nextRequestAt = slot.add(_requestGap);
    final wait = slot.difference(now);
    return wait <= Duration.zero ? Future.value() : Future<void>.delayed(wait);
  }

  /// Only reads run through the pool, so retrying is safe. Rate limits use
  /// the server's wait; transient errors get one short exponential backoff.
  static Future<void> _withRetry(Future<void> Function() job) async {
    for (var attempt = 1; ; attempt++) {
      await _throttle();
      try {
        return await job();
      } on ParqetException catch (e) {
        final maxAttempts = switch (e.kind) {
          ParqetErrorKind.rateLimited => 4,
          ParqetErrorKind.network => 2,
          ParqetErrorKind.server when (e.statusCode ?? 500) >= 500 => 2,
          _ => 1,
        };
        if (attempt >= maxAttempts) {
          errorLog('[DepotParqetSync] Giving up after $attempt attempt(s): $e');
          rethrow;
        }
        final delay = _retryDelay(e, attempt);
        errorLog(
          '[DepotParqetSync] Attempt $attempt failed '
          '(${e.kind.name}), retrying in ${delay.inMilliseconds} ms: $e',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  static Duration _retryDelay(ParqetException error, int attempt) {
    final serverWait = error.retryAfter;
    if (serverWait != null) return serverWait;
    final backoff = _retryBase * (1 << (attempt - 1));
    final capped = backoff > _retryMax ? _retryMax : backoff;
    return capped + Duration(milliseconds: _random.nextInt(500));
  }
}

/// Reads activities by comparing Parqet's per-holding activity counts with
/// those of the last read, which also catches backdated and deleted bookings.
class _ActivityPull {
  final ParqetApi api;
  final transactions = <DepotTransaction>[];
  final complete = <String>{};
  final reloaded = <String, Set<String>>{};

  _ActivityPull(this.api);

  List<Future<void> Function()> jobs(
    String portfolioId, {
    required bool full,
    required Map<String, int>? known,
    required Map<String, int> current,
  }) {
    if (full) return [() => _readAll(portfolioId)];
    // Without counts from Parqet only the newest bookings can be found.
    if (current.isEmpty) return [() => _readNewest(portfolioId)];
    if (known == null) return [() => _readAll(portfolioId)];
    final changed = {
      for (final MapEntry(:key, :value) in current.entries)
        if (known[key] != value) key,
      for (final id in known.keys)
        if (!current.containsKey(id)) id,
    };
    if (changed.length > DepotParqetSync._maxHoldingReads) {
      return [() => _readAll(portfolioId)];
    }
    reloaded[portfolioId] = changed;
    return [
      // Bookings of holdings Parqet does not list, e.g. cash, have no count.
      () => _readNewest(portfolioId),
      for (final id in changed)
        if (current.containsKey(id))
          () async => transactions.addAll(
            (await api.activities(portfolioId, holdingId: id)).items,
          ),
    ];
  }

  Future<void> _readAll(String portfolioId) async {
    final activities = await api.activities(portfolioId);
    transactions.addAll(activities.items);
    if (activities.complete) complete.add(portfolioId);
  }

  Future<void> _readNewest(String portfolioId) async {
    final newest = await DepotStore.instance.newestTransactionAt(portfolioId);
    final activities = await api.activities(
      portfolioId,
      since: newest?.subtract(DepotParqetSync._activityOverlap),
    );
    transactions.addAll(activities.items);
    if (activities.complete) complete.add(portfolioId);
  }
}

class _PerformancePull {
  final ParqetApi api;
  final List<DepotPortfolio> portfolios;
  final holdings = <DepotHolding>[];
  final quotes = <DepotHolding>[];
  final activityCounts = <String, Map<String, int>>{};
  final holdingPerformance = <DepotHoldingPerformance>[];
  final summaries = <DepotSummary>[];
  final charts = <DepotPeriodKey, List<DepotChartPoint>>{};

  _PerformancePull(this.api, this.portfolios);

  List<Future<void> Function()> jobs(
    Set<DepotPeriod> periods, {
    required bool combined,
  }) => [
    for (final period in periods) ...[
      for (final portfolio in portfolios)
        () => _load(portfolio.id, period, [portfolio.id]),
      if (combined && portfolios.length > 1)
        () => _load(DepotStore.allScope, period, [
          for (final p in portfolios.take(DepotParqetSync._maxCombined)) p.id,
        ]),
    ],
  ];

  Future<void> _load(String scope, DepotPeriod period, List<String> ids) async {
    final key = (scope: scope, period: period);
    final performance = await api.performance(
      key: key,
      portfolioIds: ids,
      currency: portfolios.first.currency,
    );
    if (ids.length == 1) {
      if (period == DepotPeriod.max) {
        holdings.addAll(performance.holdings);
        activityCounts[scope] = performance.activityCounts;
      } else {
        quotes.addAll(performance.holdings);
      }
      holdingPerformance.addAll(performance.holdingPerformance);
    }
    summaries.add(performance.summary);
    charts[key] = performance.chart;
    if (portfolios.length == 1) {
      summaries.add(performance.summary.withScope(DepotStore.allScope));
      charts[(scope: DepotStore.allScope, period: period)] = performance.chart;
    }
  }
}
