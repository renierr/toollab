import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_allocation_state.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../depot_risk.dart';
import '../depot_state.dart';
import '../depot_xray.dart';
import '../models/depot_filters.dart';
import '../models/depot_period.dart';
import 'depot_connect_card.dart';
import 'depot_drawdown_card.dart';
import 'depot_benchmark_chart.dart';
import 'depot_capital_flow_card.dart';
import 'depot_holding_filter_bar.dart';
import 'depot_holding_tile.dart';
import 'depot_kpi_grid.dart';
import 'depot_movers_card.dart';
import 'depot_period_selector.dart';
import 'depot_risk_card.dart';
import 'depot_savings_plan_card.dart';
import 'depot_section_scroll_view.dart';
import 'depot_sync_header.dart';
import 'depot_value_card.dart';

enum _Section { value, movers, growth, plans, drawdowns, risk, holdings }

class DepotOverviewView extends StatelessWidget {
  const DepotOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();
    final allocation = context.watch<DepotAllocationState>();

    if (!state.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.isConnected && !state.hasData) return const DepotConnectCard();
    if (!allocation.isLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) allocation.ensureLoaded();
      });
    }

    final summary = state.summary;
    final format = DepotFormat.of(context, state.currency);
    final holdings = state.visibleHoldings;
    final openValue = state.openValue;
    final periodLabel = DepotPortfolioLabels.period(l10n, state.period);
    final plans = state.savingsPlans;
    final drawdowns = state.drawdowns;

    return DepotSectionScrollView<_Section>(
      onRefresh: state.sync,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      spacing: 12,
      header: [
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
        else
          const SizedBox(height: 4),
      ],
      sections: !state.hasData
          ? const []
          : [
              DepotSection(
                id: _Section.value,
                label: l10n.depotKpiValue,
                icon: Icons.show_chart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DepotPeriodSelector(),
                    const SizedBox(height: 12),
                    if (summary != null) ...[
                      DepotKpiGrid(
                        summary: summary,
                        format: format,
                        valueTrend: [for (final p in state.chart) p.value],
                      ),
                      const SizedBox(height: 12),
                    ],
                    DepotValueCard(
                      points: state.chart,
                      change: state.rangeChange,
                      allocation: state.allocation,
                      format: format,
                      showChart: state.period != DepotPeriod.today,
                      chart: DepotBenchmarkChart(format: format),
                    ),
                  ],
                ),
              ),
              if (state.movers.isNotEmpty || state.gainMovers.isNotEmpty)
                DepotSection(
                  id: _Section.movers,
                  label: l10n.depotNavMovers,
                  icon: Icons.swap_vert,
                  child: DepotMoversCard(
                    movers: state.moversByGain
                        ? state.gainMovers
                        : state.movers,
                    byGain: state.moversByGain,
                    onModeChanged: state.setMoversByGain,
                    periodLabel: periodLabel,
                    format: format,
                  ),
                ),
              if (state.maxChart.length > 1)
                DepotSection(
                  id: _Section.growth,
                  label: l10n.depotNavGrowth,
                  icon: Icons.stacked_bar_chart,
                  child: DepotCapitalFlowCard(
                    points: state.maxChart,
                    transactions: state.transactions,
                    returns: state.monthlyReturns,
                    format: format,
                    inPercent: state.flowInPercent,
                    onModeChanged: state.setFlowInPercent,
                  ),
                ),
              if (!plans.isEmpty)
                DepotSection(
                  id: _Section.plans,
                  label: l10n.depotNavPlans,
                  icon: Icons.event_repeat,
                  child: DepotSavingsPlanCard(
                    plans: plans,
                    holdings: state.holdings,
                  ),
                ),
              if (!drawdowns.isEmpty)
                DepotSection(
                  id: _Section.drawdowns,
                  label: l10n.depotNavHighsLows,
                  icon: Icons.ssid_chart,
                  child: DepotDrawdownCard(
                    drawdowns: drawdowns,
                    format: format,
                    showRises: state.showRises,
                    onModeChanged: state.setShowRises,
                  ),
                ),
              DepotSection(
                id: _Section.risk,
                label: l10n.depotNavRisk,
                icon: Icons.shield_outlined,
                child: DepotRiskCard(
                  risk: DepotRisk.calculate(
                    state.holdings,
                    state.chart,
                    profileOf: allocation.profileOf,
                  ),
                  format: format,
                  xray: depotXRay(
                    holdings: state.holdings,
                    profileOf: allocation.profileOf,
                    kindOf: allocation.kindOf,
                  ),
                  periodLabel: periodLabel,
                  portfolioNames: state.portfolios.length > 1
                      ? {for (final p in state.portfolios) p.id: p.name}
                      : const {},
                  onOpenAllocation: () =>
                      context.read<DepotState>().setTab(DepotTab.allocation),
                ),
              ),
              DepotSection(
                id: _Section.holdings,
                label: l10n.depotNavHoldings,
                icon: Icons.list_alt,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: DepotHoldingFilterBar(),
                ),
              ),
            ],
      slivers: [
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
            sliver: state.holdingFilter.sort == DepotHoldingSort.custom
                ? SliverReorderableList(
                    itemCount: holdings.length,
                    onReorderItem: state.reorderHolding,
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 4,
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final holding = holdings[index];
                      return DepotHoldingTile(
                        key: ValueKey(holding.key),
                        holding: holding,
                        performance: state.performanceOf(holding),
                        period: state.period,
                        format: format,
                        weight: openValue <= 0
                            ? 0
                            : holding.currentValue / openValue * 100,
                        reorderIndex: index,
                      );
                    },
                  )
                : SliverList.builder(
                    itemCount: holdings.length,
                    itemBuilder: (context, index) {
                      final holding = holdings[index];
                      return DepotHoldingTile(
                        key: ValueKey(holding.key),
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
    );
  }
}
