import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_allocation.dart';
import '../depot_allocation_state.dart';
import '../depot_allocation_sync.dart';
import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_fund_costs.dart';
import '../depot_overlap.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../depot_region.dart';
import '../depot_xray.dart';
import 'depot_connect_card.dart';
import 'depot_fund_cost_card.dart';
import 'depot_overlap_card.dart';
import 'depot_section_scroll_view.dart';
import 'depot_share_breakdown.dart';
import 'depot_weight_list.dart';
import 'depot_xray_card.dart';

enum _Section { positions, xray, overlap, cost, region, sector, industry }

/// Region, sector and industry split of the open positions.
class DepotAllocationTabView extends StatelessWidget {
  const DepotAllocationTabView({super.key});

  static const int _maxIndustryEntries = 8;
  static const String _otherIndustries = '\u0000other';
  static const String _usd = 'USD';

  /// The dollar move the footnote prices in.
  static const double _usdDrop = 0.1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final portfolio = context.watch<DepotPortfolioState>();
    final allocation = context.watch<DepotAllocationState>();

    if (!portfolio.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!portfolio.isConnected && !portfolio.hasData) {
      return const DepotConnectCard();
    }

    final holdings = portfolio.holdings;
    final open = [
      for (final holding in holdings)
        if (!holding.isSold && holding.currentValue > 0) holding,
    ];
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => allocation.ensureLoaded(),
    );

    final format = DepotFormat.of(context, portfolio.currency);
    final sectors = depotAllocationBreakdown(
      holdings: holdings,
      profileOf: allocation.profileOf,
      dimension: DepotAllocationDimension.sector,
    );
    final regions = depotAllocationBreakdown(
      holdings: holdings,
      profileOf: allocation.profileOf,
      dimension: DepotAllocationDimension.region,
    );
    final industries = depotAllocationBreakdown(
      holdings: holdings,
      profileOf: allocation.profileOf,
      dimension: DepotAllocationDimension.industry,
      kindOf: allocation.kindOf,
      constituentProfileOf: allocation.constituentProfileOf,
    );
    final xray = depotXRay(
      holdings: open,
      profileOf: allocation.profileOf,
      kindOf: allocation.kindOf,
    );
    final overlap = depotOverlap(
      holdings: open,
      profileOf: allocation.profileOf,
      kindOf: allocation.kindOf,
    );
    final costs = depotFundCosts(
      holdings: open,
      profileOf: allocation.profileOf,
      kindOf: allocation.kindOf,
    );
    final usd = depotUsdExposure(
      holdings: open,
      profileOf: allocation.profileOf,
      kindOf: allocation.kindOf,
    );
    final usdNote = portfolio.currency != _usd && usd.usd > 0
        ? l10n.depotAllocationUsdExposure(
            format.percent(usd.usd / usd.known * 100, signed: false),
            format.axisMoney(-usd.usd * _usdDrop),
          )
        : null;

    return DepotSectionScrollView<_Section>(
      onRefresh: () => syncDepotAllocation(portfolio, allocation),
      header: [
        if (allocation.isFetching)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              l10n.depotAllocationEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
      sections: open.isEmpty
          ? const []
          : [
              DepotSection(
                id: _Section.positions,
                label: l10n.depotAllocationPositions,
                icon: Icons.donut_large_outlined,
                child: DepotWeightList(
                  holdings: open,
                  format: format,
                  kindOf: allocation.kindOf,
                  constituentsOf: (holding) =>
                      allocation.profileOf(holding)?.constituents ?? const [],
                ),
              ),
              if (xray.hasLookThrough)
                DepotSection(
                  id: _Section.xray,
                  label: l10n.depotXRayTitle,
                  icon: Icons.manage_search_outlined,
                  child: DepotXRayCard(xray: xray, format: format),
                ),
              if (overlap.hasPairs)
                DepotSection(
                  id: _Section.overlap,
                  label: l10n.depotOverlapTitle,
                  icon: Icons.join_inner_outlined,
                  child: DepotOverlapCard(overlap: overlap, format: format),
                ),
              if (costs.hasCosts)
                DepotSection(
                  id: _Section.cost,
                  label: l10n.depotFundCostNav,
                  icon: Icons.savings_outlined,
                  child: DepotFundCostCard(costs: costs, format: format),
                ),
              DepotSection(
                id: _Section.region,
                label: l10n.depotAllocationByRegion,
                icon: Icons.public_outlined,
                child: DepotShareBreakdown(
                  title: l10n.depotAllocationByRegion,
                  entries: _entries(
                    context,
                    regions,
                    (key) => DepotPortfolioLabels.region(
                      l10n,
                      DepotRegion.values.byName(key),
                    ),
                  ),
                  format: format,
                  footnote: usdNote,
                ),
              ),
              DepotSection(
                id: _Section.sector,
                label: l10n.depotAllocationBySector,
                icon: Icons.pie_chart_outline,
                child: DepotShareBreakdown(
                  title: l10n.depotAllocationBySector,
                  entries: _entries(
                    context,
                    sectors,
                    (key) => DepotPortfolioLabels.sector(l10n, key),
                  ),
                  format: format,
                ),
              ),
              DepotSection(
                id: _Section.industry,
                label: l10n.depotAllocationByIndustry,
                icon: Icons.factory_outlined,
                child: DepotShareBreakdown(
                  title: l10n.depotAllocationByIndustry,
                  entries: _entries(
                    context,
                    _trimIndustries(industries),
                    (key) => switch (key) {
                      _otherIndustries => l10n.depotAllocationOtherIndustries,
                      depotAllocationFundRest => l10n.depotAllocationFundRest,
                      _ => key,
                    },
                  ),
                  format: format,
                ),
              ),
            ],
    );
  }

  List<DepotShareEntry> _entries(
    BuildContext context,
    Map<String?, double> values,
    String Function(String key) labelOf,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return [
      for (final entry in values.entries)
        if (entry.value > 0)
          DepotShareEntry(
            label: entry.key == null
                ? l10n.depotAllocationUnclassified
                : labelOf(entry.key!),
            value: entry.value,
            color: switch (entry.key) {
              null => theme.hintColor.withValues(alpha: 0.6),
              depotAllocationFundRest => theme.colorScheme.outlineVariant,
              final key => DepotColors.holding(key),
            },
          ),
    ];
  }

  /// Folds the smallest industries together; unknown and fund-rest values
  /// keep their own entries, listed last.
  Map<String?, double> _trimIndustries(Map<String?, double> industries) {
    bool named(String? key) => key != null && key != depotAllocationFundRest;
    final entries = industries.entries.where((e) => named(e.key)).toList();
    final folds = entries.length > _maxIndustryEntries;
    final kept = folds ? entries.take(_maxIndustryEntries - 1) : entries;
    return {
      for (final entry in kept) entry.key: entry.value,
      if (folds)
        _otherIndustries: entries
            .skip(_maxIndustryEntries - 1)
            .fold<double>(0, (sum, entry) => sum + entry.value),
      for (final entry in industries.entries)
        if (!named(entry.key)) entry.key: entry.value,
    };
  }
}
