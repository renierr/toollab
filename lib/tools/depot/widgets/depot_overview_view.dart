import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import 'depot_allocation_card.dart';
import 'depot_connect_card.dart';
import 'depot_holding_filter_bar.dart';
import 'depot_holding_tile.dart';
import 'depot_income_chart.dart';
import 'depot_kpi_grid.dart';
import 'depot_sync_header.dart';
import 'depot_value_chart.dart';

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
    final openValue = state.holdings
        .where((h) => !h.isSold)
        .fold<double>(0, (sum, h) => sum + h.currentValue);

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
                  if (summary == null)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.depotNoDataYet,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    DepotKpiGrid(
                      summary: summary,
                      format: format,
                      valueTrend: [for (final p in state.chartInRange) p.value],
                    ),
                    const SizedBox(height: 12),
                    DepotValueChart(
                      points: state.chartInRange,
                      change: state.rangeChange,
                      range: state.range,
                      format: format,
                      onRangeChanged: state.setRange,
                    ),
                    DepotAllocationCard(
                      allocation: state.allocation,
                      format: format,
                    ),
                    DepotIncomeChart(
                      months: state.incomeByMonth(),
                      format: format,
                    ),
                    const SizedBox(height: 16),
                    const DepotHoldingFilterBar(),
                  ],
                ],
              ),
            ),
            if (summary != null && holdings.isEmpty)
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
            if (summary != null)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList.builder(
                  itemCount: holdings.length,
                  itemBuilder: (context, index) {
                    final holding = holdings[index];
                    return DepotHoldingTile(
                      holding: holding,
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
