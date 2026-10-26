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
  static const _maxConcurrent = 4;
  static const _activityOverlap = Duration(days: 3);

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
    final priority = _PerformancePull(client, portfolios);
    await _runPooled(priority.jobs({period}, combined: true));
    await store.savePerformance(
      portfolios: portfolios,
      holdings: period == DepotPeriod.max ? priority.holdings : null,
      summaries: priority.summaries,
      charts: priority.charts,
      holdingPerformance: priority.holdingPerformance,
    );
    await onPeriodReady?.call();

    final transactions = <DepotTransaction>[];
    final completeActivities = <String>{};
    final remaining = _PerformancePull(client, portfolios);
    final periods = full
        ? DepotPeriod.values.where((p) => p != period).toSet()
        : {if (period != DepotPeriod.max) DepotPeriod.max};
    final jobs = [
      ...remaining.jobs(periods, combined: full),
      for (final portfolio in portfolios)
        () async {
          final since = full
              ? null
              : (await store.newestTransactionAt(
                  portfolio.id,
                ))?.subtract(_activityOverlap);
          final activities = await client.activities(
            portfolio.id,
            since: since,
          );
          transactions.addAll(activities.items);
          if (activities.complete) completeActivities.add(portfolio.id);
        },
    ];
    await _runPooled(jobs);

    final holdings = [...priority.holdings, ...remaining.holdings];
    await store.replaceAll(
      portfolios: portfolios,
      holdings: holdings,
      holdingPerformance: remaining.holdingPerformance,
      transactions: transactions,
      summaries: remaining.summaries,
      charts: remaining.charts,
      completeActivityPortfolios: completeActivities,
    );

    final detail =
        '${portfolios.length} portfolios, ${holdings.length} holdings, '
        '${transactions.length} activities';
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
    );
  }

  static Future<void> _runPooled(List<Future<void> Function()> jobs) async {
    var next = 0;
    Object? failure;
    StackTrace? failureStack;

    Future<void> worker() async {
      while (failure == null && next < jobs.length) {
        final job = jobs[next++];
        try {
          await _withRetry(job);
        } catch (e, stack) {
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

  static Future<void> _withRetry(Future<void> Function() job) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await job();
      } on ParqetException catch (e) {
        if (e.kind != ParqetErrorKind.rateLimited || attempt >= 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }
}

class _PerformancePull {
  final ParqetApi api;
  final List<DepotPortfolio> portfolios;
  final holdings = <DepotHolding>[];
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
      if (period == DepotPeriod.max) holdings.addAll(performance.holdings);
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
