import 'package:flutter/material.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../models/depot_transaction.dart';

class DepotTransactionTile extends StatelessWidget {
  final DepotTransaction transaction;
  final DepotFormat format;

  const DepotTransactionTile({
    super.key,
    required this.transaction,
    required this.format,
  });

  static (IconData, Color) _style(DepotTransactionType type) => switch (type) {
    DepotTransactionType.buy => (Icons.add_shopping_cart, AppTheme.accentBlue),
    DepotTransactionType.sell => (Icons.sell_outlined, AppTheme.accentAmber),
    DepotTransactionType.dividend => (
      Icons.payments_outlined,
      AppTheme.accentTeal,
    ),
    DepotTransactionType.interest => (Icons.percent, AppTheme.accentTeal),
    DepotTransactionType.transferIn => (Icons.login, AppTheme.accentPurple),
    DepotTransactionType.transferOut => (Icons.logout, AppTheme.accentPurple),
    DepotTransactionType.feesTaxes => (
      Icons.receipt_long_outlined,
      AppTheme.accentRed,
    ),
    DepotTransactionType.deposit => (Icons.south_west, AppTheme.accentGreen),
    DepotTransactionType.withdrawal => (Icons.north_east, AppTheme.accentRed),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = transaction;
    final (icon, color) = _style(t.type);
    final typeLabel = DepotPortfolioLabels.transactionType(l10n, t.type);
    final realized = t.realizedGain;
    final subtitle = [
      FormatHelper.dateTime(t.datetime, style: DateStyle.dateOnly),
      if (t.holdingName.isNotEmpty) typeLabel,
      if (t.shares != 0 && t.price != 0)
        '${format.shares(t.shares)} × ${format.money(t.price)}',
      ?t.broker,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        t.holdingName.isEmpty ? typeLabel : t.holdingName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            format.money(t.amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (realized != null)
            Text(
              format.money(realized, signed: true),
              style: theme.textTheme.bodySmall?.copyWith(
                color: DepotFormat.gainColor(realized),
              ),
            ),
        ],
      ),
    );
  }
}
