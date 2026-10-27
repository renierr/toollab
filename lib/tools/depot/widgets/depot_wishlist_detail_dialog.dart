import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../depot_wishlist_state.dart';
import '../models/depot_wishlist.dart';
import 'depot_holding_avatar.dart';
import 'depot_wishlist_chart.dart';

/// Every figure the local wishlist holds for one security.
class DepotWishlistDetailDialog extends StatelessWidget {
  final DepotWishlistItem item;

  const DepotWishlistDetailDialog({super.key, required this.item});

  static Future<void> show(BuildContext context, DepotWishlistItem item) =>
      showDialog<void>(
        context: context,
        builder: (_) => DepotWishlistDetailDialog(item: item),
      );

  Future<void> _remove(BuildContext context) async {
    final removed = await context.read<DepotWishlistState>().remove(
      item.symbol,
    );
    if (!context.mounted) return;
    if (removed) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).depotWishlistRemoveFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final quote = context.select<DepotWishlistState, DepotWishlistQuote?>(
      (state) => state.quoteFor(item.symbol),
    );
    final format = DepotFormat.of(context, quote?.currency ?? item.currency);
    final locale = Localizations.localeOf(context).toString();
    final addedOn = DateFormat.yMMMd(locale).format(item.addedAt);
    final quoteAt = quote?.quoteAt;
    final dayChange = quote?.dayChangePercent;
    final yearChange = quote?.changeSince(const Duration(days: 365));
    final sinceAdded = item.addedPrice == null
        ? null
        : quote?.changeFrom(item.addedPrice!);
    final quoteColor = yearChange == null
        ? theme.hintColor
        : yearChange > 0
        ? AppTheme.statusGreen
        : yearChange < 0
        ? AppTheme.statusRed
        : theme.hintColor;

    String range(double? low, double? high) {
      if (low == null || high == null) return '';
      return '${format.money(low)} – ${format.money(high)}';
    }

    String percentOrEmpty(double? value) =>
        value == null ? '' : format.percent(value);

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Row(
        children: [
          DepotHoldingAvatar(name: item.name, colorSeed: item.symbol),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.titleMedium),
                Text(
                  '${item.symbol} · '
                  '${DepotPortfolioLabels.kind(l10n, item.kind)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quote == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.depotWishlistQuoteFailed,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            )
          else ...[
            Text(l10n.depotWishlistChart, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            DepotWishlistChart(
              points: quote.points,
              format: format,
              color: quoteColor,
            ),
            const SizedBox(height: 12),
          ],
          for (final (label, value) in [
            (l10n.depotDetailExchange, item.exchange),
            (
              l10n.depotWishlistPrice,
              quote == null ? '' : format.money(quote.price),
            ),
            (
              l10n.depotWishlistToday,
              quote == null ? '' : percentOrEmpty(dayChange),
            ),
            (
              l10n.depotWishlistRange1m,
              quote == null
                  ? ''
                  : percentOrEmpty(quote.changeSince(const Duration(days: 31))),
            ),
            (
              l10n.depotWishlistRange6m,
              quote == null
                  ? ''
                  : percentOrEmpty(
                      quote.changeSince(const Duration(days: 183)),
                    ),
            ),
            (
              l10n.depotWishlistRange1y,
              quote == null ? '' : percentOrEmpty(yearChange),
            ),
            (
              l10n.depotWishlistAddedPrice,
              item.addedPrice == null ? '' : format.money(item.addedPrice!),
            ),
            (l10n.depotWishlistSinceAdded, percentOrEmpty(sinceAdded)),
            (l10n.depotWishlistAddedOn, addedOn),
            (
              l10n.depotWishlistDayRange,
              quote == null ? '' : range(quote.dayLow, quote.dayHigh),
            ),
            (
              l10n.depotWishlistYearRange,
              quote == null ? '' : range(quote.yearLow, quote.yearHigh),
            ),
            (
              l10n.depotDetailQuoteAt,
              quoteAt == null
                  ? ''
                  : DateFormat.yMMMd(locale).add_Hm().format(quoteAt),
            ),
          ])
            if (value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: InfoRow(label: label, value: value),
              ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _remove(context),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.depotWishlistRemove),
          style: TextButton.styleFrom(foregroundColor: AppTheme.statusRed),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
