import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_wishlist.dart';
import 'depot_holding_avatar.dart';
import 'depot_market_sparkline.dart';

/// One wishlist entry: name, 24-hour trend, price and today's move.
class DepotWishlistRow extends StatelessWidget {
  final DepotWishlistItem item;
  final DepotWishlistQuote? quote;
  final bool failed;
  final double? euroRate;
  final Uint8List? logoBytes;
  final VoidCallback onTap;

  const DepotWishlistRow({
    super.key,
    required this.item,
    required this.quote,
    required this.failed,
    this.euroRate,
    this.logoBytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = DepotFormat.of(
      context,
      euroRate == null ? (quote?.currency ?? item.currency) : 'EUR',
    );
    final dayChange = quote?.dayChangePercent;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The price and change already carry the trend; the line goes first
        // when there is not enough room for the name next to it.
        final cramped = constraints.maxWidth < 380;
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                DepotHoldingAvatar(
                  name: item.name,
                  colorSeed: item.symbol,
                  logoBytes: logoBytes,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${item.symbol} · '
                        '${DepotPortfolioLabels.kind(l10n, item.kind)}'
                        '${item.isin == null ? '' : ' · ${item.isin}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (quote != null && !cramped)
                  DepotMarketSparkline(
                    symbol: item.symbol,
                    currency: quote!.currency,
                    points: quote!.points,
                  ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 72),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (quote == null)
                        failed
                            ? Tooltip(
                                message: l10n.depotWishlistQuoteFailed,
                                child: Icon(
                                  Icons.cloud_off_outlined,
                                  size: 18,
                                  color: theme.hintColor,
                                ),
                              )
                            : const SizedBox(height: 18),
                      if (quote != null) ...[
                        if (failed)
                          Tooltip(
                            message: l10n.depotWishlistQuoteFailed,
                            child: Icon(
                              Icons.cloud_off_outlined,
                              size: 18,
                              color: theme.hintColor,
                            ),
                          ),
                        Text(
                          '${euroRate != null && quote!.currency != 'EUR' ? '≈ ' : ''}'
                          '${format.money(quote!.price * (euroRate ?? 1))}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (dayChange != null)
                          Text(
                            format.percent(dayChange),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: DepotFormat.gainColor(dayChange),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
