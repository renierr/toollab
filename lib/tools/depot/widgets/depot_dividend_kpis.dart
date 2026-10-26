import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../dividends/depot_dividend_calendar.dart';
import 'depot_dividend_list_dialog.dart';

class DepotDividendKpis extends StatelessWidget {
  final DepotDividendCalendar calendar;
  final DepotFormat format;

  const DepotDividendKpis({
    super.key,
    required this.calendar,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final forwardYield = calendar.forwardYield;
    final missing = calendar.missingNet;
    final receivedYearLabel = l10n.depotDividendReceivedYear(
      '${calendar.today.year}',
    );
    void list(
      String title,
      List<DepotDividendEntry> entries, {
      bool newestFirst = true,
    }) => DepotDividendListDialog.show(
      context,
      title: title,
      entries: entries,
      format: format,
      newestFirst: newestFirst,
    );

    return MetricGrid(
      children: [
        MetricTile(
          label: l10n.depotDividendReceived12m,
          value: format.money(calendar.receivedNet12m),
          icon: Icons.payments_outlined,
          color: DepotColors.dividendBooked,
          compact: true,
          onTap: () =>
              list(l10n.depotDividendReceived12m, calendar.received12m),
        ),
        MetricTile(
          label: receivedYearLabel,
          value: format.money(calendar.receivedNetThisYear),
          icon: Icons.event_available_outlined,
          color: DepotColors.dividendBooked,
          compact: true,
          onTap: () => list(receivedYearLabel, calendar.receivedThisYear),
        ),
        MetricTile(
          label: l10n.depotDividendExpected12m,
          value: '≈ ${format.money(calendar.expectedNet12m)}',
          icon: Icons.upcoming_outlined,
          color: DepotColors.dividendExpected,
          compact: true,
          onTap: () => list(
            l10n.depotDividendExpected12m,
            calendar.expected12m,
            newestFirst: false,
          ),
        ),
        if (forwardYield != null)
          MetricTile(
            label: l10n.depotDividendYield,
            value: format.percent(forwardYield, signed: false),
            icon: Icons.percent,
            color: DepotColors.dividendExpected,
            compact: true,
          ),
        if (missing > 0)
          MetricTile(
            label: l10n.depotDividendStatusMissing,
            value: '≈ ${format.money(missing)}',
            icon: Icons.report_outlined,
            color: DepotColors.dividendMissing,
            compact: true,
            onTap: () =>
                list(l10n.depotDividendStatusMissing, calendar.missing),
          ),
      ],
    );
  }
}
