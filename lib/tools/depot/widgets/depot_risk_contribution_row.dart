import 'package:flutter/material.dart';

import '../depot_format.dart';
import '../depot_risk.dart';
import 'depot_info_row.dart';

class DepotRiskContributionRow extends StatelessWidget {
  final DepotRiskContribution contribution;
  final DepotFormat format;
  final Map<String, String> portfolioNames;

  const DepotRiskContributionRow({
    super.key,
    required this.contribution,
    required this.format,
    this.portfolioNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final portfolio = portfolioNames[contribution.holding.portfolioId];
    return DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(contribution.holding.name),
      subtitle: portfolio == null
          ? null
          : Text(
              portfolio,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
      trailing: Text(
        format.percent(contribution.weight, signed: false),
        textAlign: TextAlign.end,
      ),
    );
  }
}
