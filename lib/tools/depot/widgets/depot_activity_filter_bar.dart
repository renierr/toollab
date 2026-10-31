import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_transaction.dart';
import 'depot_search_field.dart';
import 'depot_activity_range_filter.dart';
import 'depot_activity_export_button.dart';

class DepotActivityFilterBar extends StatelessWidget {
  const DepotActivityFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();
    final filter = state.activityFilter;
    final presentTypes = {for (final t in state.transactions) t.type};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.depotActivitiesCount(state.visibleTransactions.length),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DepotSearchField(
          initialText: filter.query,
          hint: l10n.depotActivitiesSearch,
          onChanged: (q) =>
              state.setActivityFilter(state.activityFilter.copyWith(query: q)),
        ),
        if (filter.holdingId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(filter.holdingName ?? filter.holdingId!),
              onDeleted: () =>
                  state.setActivityFilter(filter.copyWith(clearHolding: true)),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final type in DepotTransactionType.values)
              if (presentTypes.contains(type))
                FilterChip(
                  label: Text(DepotPortfolioLabels.transactionType(l10n, type)),
                  selected: filter.types.contains(type),
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) => state.setActivityFilter(
                    state.activityFilter.copyWith(
                      types: on
                          ? {...state.activityFilter.types, type}
                          : ({...state.activityFilter.types}..remove(type)),
                    ),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 8),
        const DepotActivityRangeFilter(),
        const DepotActivityExportButton(),
      ],
    );
  }
}
