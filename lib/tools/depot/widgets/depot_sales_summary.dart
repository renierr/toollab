import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../models/depot_transaction.dart';
import 'depot_info_row.dart';

class DepotSalesSummary extends StatelessWidget {
  final List<DepotTransaction> transactions;
  final int year;

  const DepotSalesSummary({
    super.key,
    required this.transactions,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sales = transactions
        .where(
          (t) => t.datetime.year == year && t.type == DepotTransactionType.sell,
        )
        .toList();
    if (sales.isEmpty) return const SizedBox.shrink();
    final currencies = <String, List<DepotTransaction>>{};
    var unknown = 0;
    for (final sale in sales) {
      final currency = sale.currency.trim().toUpperCase();
      if (currency.isEmpty) {
        unknown++;
      } else {
        currencies.putIfAbsent(currency, () => []).add(sale);
      }
    }
    final codes = currencies.keys.toList()..sort();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l10n.depotSalesTitle),
      children: [
        for (final code in codes)
          _SalesCurrency(currency: code, sales: currencies[code]!),
        if (unknown > 0) Text(l10n.depotYearUnknownCurrency(unknown)),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            l10n.depotSalesNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesCurrency extends StatelessWidget {
  final String currency;
  final List<DepotTransaction> sales;
  const _SalesCurrency({required this.currency, required this.sales});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = DepotFormat.of(context, currency);
    final proceeds = sales.fold<double>(0, (v, t) => v + t.amountNet);
    final known = sales.where((t) => t.realizedGain != null).toList()
      ..sort((a, b) => b.realizedGain!.compareTo(a.realizedGain!));
    final missing = sales.length - known.length;
    final gain = known.fold<double>(0, (v, t) => v + t.realizedGain!);
    final best = known.where((t) => t.realizedGain! > 0).take(3).toList();
    final worst = known.reversed
        .where((t) => t.realizedGain! < 0)
        .take(3)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(currency, style: theme.textTheme.titleSmall),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                DepotInfoRow(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  title: Text(l10n.depotSalesProceeds),
                  trailing: Text(
                    format.money(proceeds),
                    textAlign: TextAlign.end,
                  ),
                ),
                if (known.isNotEmpty)
                  DepotInfoRow(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    title: Text(l10n.depotSalesKnownGain),
                    trailing: Text(
                      format.money(gain, signed: true),
                      textAlign: TextAlign.end,
                      style: TextStyle(color: DepotFormat.gainColor(gain)),
                    ),
                  ),
                if (missing > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l10n.depotSalesMissingGain(missing)),
                  ),
              ],
            ),
          ),
        ),
        if (best.isNotEmpty)
          _SalesGroup(
            title: l10n.depotSalesLargestGains,
            sales: best,
            format: format,
          ),
        if (worst.isNotEmpty)
          _SalesGroup(
            title: l10n.depotSalesLargestLosses,
            sales: worst,
            format: format,
          ),
      ],
    );
  }
}

class _SalesGroup extends StatelessWidget {
  final String title;
  final List<DepotTransaction> sales;
  final DepotFormat format;

  const _SalesGroup({
    required this.title,
    required this.sales,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(title, style: theme.textTheme.labelLarge),
        ),
        for (final sale in sales)
          DepotInfoRow(
            padding: const EdgeInsets.symmetric(vertical: 6),
            title: Text(
              sale.holdingName.isEmpty ? l10n.depotTxSell : sale.holdingName,
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              MaterialLocalizations.of(context).formatShortDate(sale.datetime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Text(
              format.money(sale.realizedGain!, signed: true),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DepotFormat.gainColor(sale.realizedGain!),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
