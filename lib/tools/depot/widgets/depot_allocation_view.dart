import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';
import 'depot_share_breakdown.dart';

/// Share of the portfolio value per asset kind.
class DepotAllocationView extends StatelessWidget {
  final Map<DepotHoldingKind, double> allocation;
  final DepotFormat format;

  const DepotAllocationView({
    super.key,
    required this.allocation,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      for (final entry in allocation.entries)
        if (entry.value > 0)
          DepotShareEntry(
            label: DepotPortfolioLabels.kinds(l10n, entry.key),
            value: entry.value,
            color: DepotColors.kind(entry.key),
          ),
    ]..sort((a, b) => b.value.compareTo(a.value));

    return DepotShareBreakdown(
      title: l10n.depotAllocationTitle,
      entries: entries,
      format: format,
    );
  }
}
