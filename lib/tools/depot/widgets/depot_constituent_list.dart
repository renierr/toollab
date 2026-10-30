import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../models/depot_fund_constituent.dart';

/// A fund's top holdings with their share of the fund and the money they
/// represent in this position.
class DepotConstituentList extends StatelessWidget {
  final List<DepotFundConstituent> constituents;
  final double fundValue;
  final DepotFormat format;

  const DepotConstituentList({
    super.key,
    required this.constituents,
    required this.fundValue,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    return Padding(
      padding: const EdgeInsets.only(left: 38, top: 4),
      child: Column(
        children: [
          for (final constituent in constituents)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      constituent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.depotXRayFundShare(
                      format.percent(constituent.weight * 100, signed: false),
                    ),
                    style: hint,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    format.money(fundValue * constituent.weight),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
