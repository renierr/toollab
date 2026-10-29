import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/readable_width.dart';

import '../depot_allocation.dart';
import '../depot_allocation_state.dart';
import '../depot_allocation_sync.dart';
import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../depot_region.dart';
import 'depot_connect_card.dart';
import 'depot_share_breakdown.dart';
import 'depot_weight_list.dart';

/// Region, sector and industry split of the open positions.
class DepotAllocationTabView extends StatelessWidget {
  const DepotAllocationTabView({super.key});

  static const int _maxIndustryEntries = 8;
  static const String _otherIndustries = '\u0000other';

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
    );

    return RefreshIndicator(
      onRefresh: () => syncDepotAllocation(portfolio, allocation),
      child: ReadableWidth(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (allocation.isFetching)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Text(
              l10n.depotAllocationSourceNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 16),
            if (open.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  l10n.depotAllocationEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              DepotWeightList(holdings: open, format: format),
              const SizedBox(height: 24),
              DepotShareBreakdown(
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
              ),
              const SizedBox(height: 24),
              DepotShareBreakdown(
                title: l10n.depotAllocationBySector,
                entries: _entries(
                  context,
                  sectors,
                  (key) => DepotPortfolioLabels.sector(l10n, key),
                ),
                format: format,
              ),
              const SizedBox(height: 24),
              DepotShareBreakdown(
                title: l10n.depotAllocationByIndustry,
                entries: _entries(
                  context,
                  _trimIndustries(industries),
                  (key) => key == _otherIndustries
                      ? l10n.depotAllocationOtherIndustries
                      : key,
                ),
                format: format,
              ),
              const SizedBox(height: 24),
              DepotShareBreakdown(
                title: l10n.depotAllocationByKind,
                entries: [
                  for (final entry in portfolio.allocation.entries)
                    if (entry.value > 0)
                      DepotShareEntry(
                        label: DepotPortfolioLabels.kinds(l10n, entry.key),
                        value: entry.value,
                        color: DepotColors.kind(entry.key),
                      ),
                ]..sort((a, b) => b.value.compareTo(a.value)),
                format: format,
              ),
            ],
          ],
        ),
      ),
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
            color: entry.key == null
                ? theme.hintColor.withValues(alpha: 0.6)
                : DepotColors.holding(entry.key!),
          ),
    ];
  }

  Map<String?, double> _trimIndustries(Map<String?, double> industries) {
    if (industries.length <= _maxIndustryEntries) return industries;
    final entries = industries.entries.toList();
    final kept = entries.take(_maxIndustryEntries - 1);
    final rest = entries.skip(_maxIndustryEntries - 1);
    return {
      for (final entry in kept) entry.key: entry.value,
      _otherIndustries: rest.fold<double>(0, (sum, entry) => sum + entry.value),
    };
  }
}
