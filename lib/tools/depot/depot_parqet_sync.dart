import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'models/depot_holding.dart';
import 'models/depot_period.dart';
import 'models/depot_summary.dart';
import 'models/depot_transaction.dart';
import 'parqet/parqet_api.dart';
import 'parqet/parqet_auth.dart';
import 'parqet/parqet_exception.dart';

/// One full pull from Parqet into [DepotStore]. Shared by the open tool and
/// the scheduled background run, so both write the same shape.
class DepotParqetSync {
  DepotParqetSync._();

  /// The API accepts at most this many portfolios per performance request.
  static const _maxCombined = 25;

  /// Parqet documents no rate limit, so stay gentle, but there is no reason
  /// to serialize 30 independent requests behind each other either.
  static const _maxConcurrent = 4;

  static Future<bool> isConnected() async {
    final clientId = await DepotStore.instance.clientId();
    if (clientId == null || clientId.isEmpty) return false;
    return await ParqetAuth.readTokens() != null;
  }

  /// Returns a short diagnostic line; throws [ParqetException].
  static Future<String> run() async {
    final store = DepotStore.instance;
    final clientId = await store.clientId();
    if (clientId == null || clientId.isEmpty) {
      throw const ParqetException(ParqetErrorKind.notConnected);
    }
    final api = ParqetApi(clientId: clientId);

    final portfolios = await api.portfolios();
    final holdings = <DepotHolding>[];
    final holdingPerformance = <DepotHoldingPerformance>[];
    final transactions = <DepotTransaction>[];
    final summaries = <DepotSummary>[];
    final charts = <DepotPeriodKey, List<DepotChartPoint>>{};

    // One currency for every request keeps the per-portfolio figures summable.
    final currency = portfolios.isEmpty ? 'EUR' : portfolios.first.currency;

    Future<void> loadPeriod(
      String scope,
      DepotPeriod period,
      List<String> ids,
    ) async {
      final key = (scope: scope, period: period);
      final performance = await api.performance(
        key: key,
        portfolioIds: ids,
        currency: currency,
      );
      // Holdings are only attributable to a single portfolio, and position
      // sizes and all-time figures come from the widest period.
      if (ids.length == 1) {
        if (period == DepotPeriod.max) holdings.addAll(performance.holdings);
        holdingPerformance.addAll(performance.holdingPerformance);
      }
      summaries.add(performance.summary);
      charts[key] = performance.chart;
    }

    final jobs = <Future<void> Function()>[
      for (final portfolio in portfolios) ...[
        for (final period in DepotPeriod.values)
          () => loadPeriod(portfolio.id, period, [portfolio.id]),
        () async => transactions.addAll(await api.activities(portfolio.id)),
      ],
      if (portfolios.length > 1)
        for (final period in DepotPeriod.values)
          () => loadPeriod(DepotStore.allScope, period, [
            for (final p in portfolios.take(_maxCombined)) p.id,
          ]),
    ];

    await _runPooled(jobs);

    if (portfolios.length == 1) {
      for (final summary in [...summaries]) {
        summaries.add(summary.withScope(DepotStore.allScope));
      }
      for (final period in DepotPeriod.values) {
        charts[(scope: DepotStore.allScope, period: period)] =
            charts[(scope: portfolios.first.id, period: period)]!;
      }
    }

    await store.replaceAll(
      portfolios: portfolios,
      holdings: holdings,
      holdingPerformance: holdingPerformance,
      transactions: transactions,
      summaries: summaries,
      charts: charts,
    );

    final detail =
        '${portfolios.length} portfolios, ${holdings.length} holdings, '
        '${transactions.length} activities';
    debugLog('[DepotParqetSync] $detail');
    return detail;
  }

  /// Runs [jobs] with at most [_maxConcurrent] in flight and rethrows the
  /// first failure once the running jobs have finished.
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

  /// Parallelism makes a 429 more likely, so give it two more tries.
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
