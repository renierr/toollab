import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import '../models/depot_period.dart';

class DepotPeriodSelector extends StatelessWidget {
  const DepotPeriodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = context.select<DepotPortfolioState, DepotPeriod>(
      (s) => s.period,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final period in DepotPeriod.values)
          ChoiceChip(
            label: Text(DepotPortfolioLabels.period(l10n, period)),
            selected: period == selected,
            visualDensity: VisualDensity.compact,
            onSelected: (_) =>
                context.read<DepotPortfolioState>().setPeriod(period),
          ),
      ],
    );
  }
}
