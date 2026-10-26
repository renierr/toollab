import 'package:tool_lab/helpers/debug_log.dart';

import 'depot_store.dart';
import 'models/depot_holding.dart';
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
    final transactions = <DepotTransaction>[];
    final summaries = <DepotSummary>[];
    final charts = <DepotChartKey, List<DepotChartPoint>>{};

    // One currency for every request keeps the per-portfolio figures summable.
    final currency = portfolios.isEmpty ? 'EUR' : portfolios.first.currency;

    Future<List<DepotChartPoint>> intraday(
      String scope,
      List<String> portfolioIds,
    ) async {
      final day = await api.performance(
        scope: scope,
        portfolioIds: portfolioIds,
        currency: currency,
        period: DepotChartPeriod.day,
      );
      return day.chart;
    }

    // Sequential on purpose: Parqet documents no rate limit, so stay gentle.
    for (final portfolio in portfolios) {
      final performance = await api.performance(
        scope: portfolio.id,
        portfolioIds: [portfolio.id],
        currency: currency,
      );
      holdings.addAll(performance.holdings);
      summaries.add(performance.summary);
      charts[(scope: portfolio.id, period: DepotChartPeriod.max)] =
          performance.chart;
      charts[(scope: portfolio.id, period: DepotChartPeriod.day)] =
          await intraday(portfolio.id, [portfolio.id]);
      transactions.addAll(await api.activities(portfolio.id));
    }

    if (portfolios.length == 1) {
      final only = portfolios.first.id;
      summaries.add(summaries.first.withScope(DepotStore.allScope));
      for (final period in DepotChartPeriod.values) {
        charts[(scope: DepotStore.allScope, period: period)] =
            charts[(scope: only, period: period)]!;
      }
    } else if (portfolios.length > 1) {
      final ids = [for (final p in portfolios.take(_maxCombined)) p.id];
      final combined = await api.performance(
        scope: DepotStore.allScope,
        portfolioIds: ids,
        currency: currency,
      );
      summaries.add(combined.summary);
      charts[(scope: DepotStore.allScope, period: DepotChartPeriod.max)] =
          combined.chart;
      charts[(scope: DepotStore.allScope, period: DepotChartPeriod.day)] =
          await intraday(DepotStore.allScope, ids);
    }

    await store.replaceAll(
      portfolios: portfolios,
      holdings: holdings,
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
