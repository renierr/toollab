import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../depot_colors.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_holding.dart';

class DepotKindBadge extends StatelessWidget {
  final DepotHoldingKind kind;

  const DepotKindBadge({super.key, required this.kind});

  static IconData icon(DepotHoldingKind kind) => switch (kind) {
    DepotHoldingKind.stock => Icons.business_outlined,
    DepotHoldingKind.etf || DepotHoldingKind.fund => Icons.layers_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: DepotPortfolioLabels.kind(AppLocalizations.of(context), kind),
    color: DepotColors.kind(kind),
    icon: icon(kind),
    rounded: false,
  );
}
