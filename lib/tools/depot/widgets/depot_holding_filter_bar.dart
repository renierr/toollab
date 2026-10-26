import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_filters.dart';
import '../models/depot_holding.dart';
import 'depot_search_field.dart';

class DepotHoldingFilterBar extends StatelessWidget {
  const DepotHoldingFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();
    final filter = state.holdingFilter;
    final presentTypes = {for (final h in state.holdings) h.assetType};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              l10n.depotHoldingsTitle(state.visibleHoldings.length),
              style: theme.textTheme.titleSmall,
            ),
            PopupMenuButton<DepotHoldingSort>(
              tooltip: l10n.depotHoldingsSort,
              initialValue: filter.sort,
              onSelected: (sort) =>
                  state.setHoldingFilter(filter.copyWith(sort: sort)),
              itemBuilder: (_) => [
                for (final sort in DepotHoldingSort.values)
                  PopupMenuItem(
                    value: sort,
                    child: Text(DepotPortfolioLabels.sort(l10n, sort)),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort, size: 18),
                    const SizedBox(width: 4),
                    Text(DepotPortfolioLabels.sort(l10n, filter.sort)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DepotSearchField(
          initialText: filter.query,
          hint: l10n.depotHoldingsSearch,
          onChanged: (q) => state.setHoldingFilter(filter.copyWith(query: q)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final type in DepotAssetType.values)
              if (presentTypes.contains(type))
                FilterChip(
                  label: Text(DepotPortfolioLabels.assetType(l10n, type)),
                  selected: filter.assetTypes.contains(type),
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => state.setHoldingFilter(
                    filter.copyWith(
                      assetTypes: on
                          ? {...filter.assetTypes, type}
                          : ({...filter.assetTypes}..remove(type)),
                    ),
                  ),
                ),
            FilterChip(
              label: Text(l10n.depotHoldingsShowSold),
              avatar: const Icon(Icons.history, size: 16),
              selected: filter.showSold,
              visualDensity: VisualDensity.compact,
              onSelected: (on) =>
                  state.setHoldingFilter(filter.copyWith(showSold: on)),
            ),
          ],
        ),
      ],
    );
  }
}
