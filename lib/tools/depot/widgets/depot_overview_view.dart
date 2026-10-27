import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_period.dart';
import 'depot_connect_card.dart';
import 'depot_holding_filter_bar.dart';
import 'depot_holding_tile.dart';
import 'depot_kpi_grid.dart';
import 'depot_movers_card.dart';
import 'depot_period_selector.dart';
import 'depot_sync_header.dart';
import 'depot_value_card.dart';

class DepotOverviewView extends StatelessWidget {
  const DepotOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();

    if (!state.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.isConnected && !state.hasData) return const DepotConnectCard();

    final summary = state.summary;
    final format = DepotFormat.of(context, state.currency);
    final holdings = state.visibleHoldings;
    final openValue = state.openValue;

    return RefreshIndicator(
      onRefresh: state.sync,
      child: ReadableWidth(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              sliver: SliverList.list(
                children: [
                  const DepotSyncHeader(),
                  if (!state.hasData)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.depotNoDataYet,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  else ...[
                    const SizedBox(height: 4),
                    const DepotPeriodSelector(),
                    const SizedBox(height: 12),
                    if (summary != null)
                      DepotKpiGrid(
                        summary: summary,
                        format: format,
                        valueTrend: [for (final p in state.chart) p.value],
                      ),
                    const SizedBox(height: 12),
                    DepotValueCard(
                      points: state.chart,
                      change: state.rangeChange,
                      allocation: state.allocation,
                      format: format,
                      showChart: state.period != DepotPeriod.today,
                    ),
                    if (state.movers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DepotMoversCard(
                        movers: state.movers,
                        periodLabel: DepotPortfolioLabels.period(
                          l10n,
                          state.period,
                        ),
                        format: format,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const DepotHoldingFilterBar(),
                  ],
                ],
              ),
            ),
            if (state.hasData && holdings.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.depotHoldingsEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            if (state.hasData)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList.builder(
                  itemCount: holdings.length,
                  itemBuilder: (context, index) {
                    final holding = holdings[index];
                    return DepotHoldingTile(
                      holding: holding,
                      performance: state.performanceOf(holding),
                      period: state.period,
                      format: format,
                      weight: openValue <= 0
                          ? 0
                          : holding.currentValue / openValue * 100,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
