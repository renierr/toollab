import 'package:flutter/material.dart';

import '../depot_format.dart';
import '../models/depot_fund_constituent.dart';
import 'depot_info_row.dart';

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
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    return Padding(
      padding: const EdgeInsets.only(left: 38, top: 4),
      child: Column(
        children: [
          for (final constituent in constituents)
            DepotInfoRow(
              padding: const EdgeInsets.symmetric(vertical: 3),
              title: Text(
                constituent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    format.percent(constituent.weight * 100, signed: false),
                    style: hint,
                    textAlign: TextAlign.end,
                  ),
                  Text(
                    format.money(fundValue * constituent.weight),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
