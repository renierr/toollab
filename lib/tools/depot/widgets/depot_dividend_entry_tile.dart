import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:tool_lab/l10n/app_localizations.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_dividend_detail_dialog.dart';
import 'depot_holding_avatar.dart';
import 'depot_info_row.dart';

class DepotDividendEntryTile extends StatelessWidget {
  final DepotDividendEntry entry;
  final DepotFormat format;

  const DepotDividendEntryTile({
    super.key,
    required this.entry,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale);
    final e = entry;
    final statusColor = DepotColors.dividend(e.status);
    final exDate = e.exDate;
    final perShare = e.perShare;
    final shares = e.shares;
    final approx = e.amountEstimated ? '≈ ' : '';

    final details = [
      dateFormat.format(e.date),
      if (exDate != null && !e.isBooked)
        l10n.depotDividendExDate(dateFormat.format(exDate)),
      if (perShare != null && shares != null)
        '${format.shares(shares)} × '
            '${NumberFormat.simpleCurrency(locale: locale, name: e.currency).format(perShare)}',
    ].join(' · ');

    return DepotInfoRow(
      onTap: () => DepotDividendDetailDialog.show(context, e, format),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: DepotHoldingAvatar(name: e.name, colorSeed: e.colorSeed),
      title: Text(
        e.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: DepotPortfolioLabels.dividendStatus(l10n, e.status),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' · $details'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$approx${format.money(e.net)}',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          if (e.gross != e.net)
            Text(
              l10n.depotDividendGross(format.money(e.gross)),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
