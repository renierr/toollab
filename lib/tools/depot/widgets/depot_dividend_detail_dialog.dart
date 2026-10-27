import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../depot_portfolio_labels.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_holding_avatar.dart';

/// Every figure of one dividend and how it was derived.
class DepotDividendDetailDialog extends StatelessWidget {
  final DepotDividendEntry entry;
  final DepotFormat format;

  const DepotDividendDetailDialog({
    super.key,
    required this.entry,
    required this.format,
  });

  static Future<void> show(
    BuildContext context,
    DepotDividendEntry entry,
    DepotFormat format,
  ) => showDialog<void>(
    context: context,
    builder: (_) => DepotDividendDetailDialog(entry: entry, format: format),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale);
    final e = entry;
    final isin = e.holding?.isin;
    final exDate = e.exDate;
    final shares = e.shares;
    final perShare = e.perShare;
    final approx = e.isBooked ? '' : '≈ ';
    final deductions = e.gross - e.net;

    final rows = <(String, String)>[
      (
        l10n.depotDividendDetailStatus,
        DepotPortfolioLabels.dividendStatus(l10n, e.status),
      ),
      if (isin != null) (l10n.depotDetailIsin, isin),
      (
        e.isBooked
            ? l10n.depotDividendDetailBookedOn
            : l10n.depotDividendDetailPayDate,
        '${e.isBooked ? '' : '≈ '}${date.format(e.date)}',
      ),
      if (exDate != null) (l10n.depotDividendDetailExDate, date.format(exDate)),
      if (shares != null) (l10n.depotDetailShares, format.shares(shares)),
      if (perShare != null)
        (
          l10n.depotDividendDetailPerShare,
          '${e.amountEstimated ? '≈ ' : ''}'
              '${NumberFormat.simpleCurrency(locale: locale, name: e.currency).format(perShare)}',
        ),
      (l10n.depotDividendDetailGross, '$approx${format.money(e.gross)}'),
      if (deductions.abs() >= 0.005)
        (
          l10n.depotDividendDetailDeductions,
          '$approx${format.money(-deductions)}',
        ),
      (l10n.depotDividendDetailNet, '$approx${format.money(e.net)}'),
    ];

    final notes = [
      switch (e.status) {
        DepotDividendStatus.booked => null,
        DepotDividendStatus.missing => l10n.depotDividendNoteMissing(
          exDate == null ? '' : date.format(exDate),
          shares == null ? '' : format.shares(shares),
        ),
        DepotDividendStatus.upcoming => l10n.depotDividendNoteUpcoming,
        DepotDividendStatus.projected => l10n.depotDividendNoteProjected,
      },
      if (e.amountEstimated) l10n.depotDividendNoteEstimatedAmount,
      if (!e.isBooked) l10n.depotDividendNoteNet,
    ].nonNulls;

    return ResponsiveAlertDialog(
      scrollable: true,
      title: Row(
        children: [
          DepotHoldingAvatar(name: e.name, colorSeed: e.colorSeed),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(e.name, style: theme.textTheme.titleMedium),
          ),
        ],
      ),
      content: SelectionArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: InfoRow(label: label, value: value),
              ),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: e.status == DepotDividendStatus.missing
                        ? DepotColors.dividendMissing
                        : theme.hintColor,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
