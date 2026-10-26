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

    // Sequential on purpose: Parqet documents no rate limit, so stay gentle.
    for (final portfolio in portfolios) {
      for (final period in DepotPeriod.values) {
        final key = (scope: portfolio.id, period: period);
        final performance = await api.performance(
          key: key,
          portfolioIds: [portfolio.id],
          currency: currency,
        );
        // Position sizes and all-time figures come from the widest period.
        if (period == DepotPeriod.max) holdings.addAll(performance.holdings);
        holdingPerformance.addAll(performance.holdingPerformance);
        summaries.add(performance.summary);
        charts[key] = performance.chart;
      }
      transactions.addAll(await api.activities(portfolio.id));
    }

    if (portfolios.length == 1) {
      for (final summary in [...summaries]) {
        summaries.add(summary.withScope(DepotStore.allScope));
      }
      for (final period in DepotPeriod.values) {
        charts[(scope: DepotStore.allScope, period: period)] =
            charts[(scope: portfolios.first.id, period: period)]!;
      }
    } else if (portfolios.length > 1) {
      final ids = [for (final p in portfolios.take(_maxCombined)) p.id];
      for (final period in DepotPeriod.values) {
        final key = (scope: DepotStore.allScope, period: period);
        final combined = await api.performance(
          key: key,
          portfolioIds: ids,
          currency: currency,
        );
        summaries.add(combined.summary);
        charts[key] = combined.chart;
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
}
