import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../depot_portfolio_state.dart';
import 'depot_info_row.dart';

/// Saver's allowance used in [year] and, for the running year, the open
/// losses that could still offset this year's gains.
class DepotTaxCard extends StatelessWidget {
  final int year;

  const DepotTaxCard({super.key, required this.year});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<DepotPortfolioState>();
    final format = DepotFormat.of(context, state.currency);
    final tax = state.taxYear(year);
    final allowance = state.taxAllowance;
    final free = tax.free(allowance);
    final running = year == DateTime.now().year;
    final offsettable = running ? tax.offsettable(allowance) : 0.0;
    final hint = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);
    final body = theme.textTheme.bodyMedium;

    return Card(
      child: ExpansionTile(
        key: const PageStorageKey('depot-tax'),
        title: Text(l10n.depotTaxTitle, style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              free > 0
                  ? l10n.depotTaxFree(
                      format.money(free),
                      format.money(allowance),
                    )
                  : l10n.depotTaxUsedUp(format.money(tax.taxes)),
              style: hint,
            ),
            if (offsettable > 0)
              Text(
                l10n.depotTaxOffsettable(format.money(offsettable)),
                style: hint,
              ),
            if (tax.advanceLumpTotal > 0)
              Text(
                l10n.depotTaxAdvanceLumpSummary(
                  format.money(tax.advanceLumpTotal),
                  format.money(tax.advanceLumpTax),
                ),
                style: hint,
              ),
          ],
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: allowance > 0 ? tax.used(allowance) / allowance : 0,
              minHeight: 6,
              color: free > 0 ? AppTheme.statusGreen : AppTheme.statusAmber,
            ),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in [
            (l10n.depotTaxIncome, tax.income),
            (l10n.depotTaxStockGains, tax.stockGains),
            (l10n.depotTaxOtherGains, tax.otherGains),
            (l10n.depotTaxExempt, -tax.exempt),
            (l10n.depotTaxPaid, tax.taxes),
          ])
            if (value != 0)
              DepotInfoRow(
                padding: const EdgeInsets.symmetric(vertical: 2),
                title: Text(label, style: body),
                trailing: Text(format.money(value), style: body),
              ),
          if (running && tax.losers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.depotTaxLosers, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final holding in tax.losers)
              DepotInfoRow(
                padding: const EdgeInsets.symmetric(vertical: 2),
                title: Text(
                  holding.name,
                  style: body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  DepotPortfolioLabels.kind(l10n, holding.kind),
                  style: hint,
                ),
                trailing: Text(
                  format.money(holding.unrealizedGain),
                  style: body?.copyWith(color: AppTheme.statusRed),
                ),
              ),
          ],
          if (tax.advanceLumps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.depotTaxAdvanceLumpTitle('${year + 1}'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            for (final lump in tax.advanceLumps)
              DepotInfoRow(
                padding: const EdgeInsets.symmetric(vertical: 2),
                title: Text(
                  lump.holding.name,
                  style: body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(format.money(lump.taxable), style: body),
              ),
          ],
        ],
      ),
    );
  }
}
