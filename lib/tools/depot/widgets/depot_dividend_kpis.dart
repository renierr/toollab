import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../depot_colors.dart';
import '../depot_format.dart';
import '../dividends/depot_dividend_calendar.dart';

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

    return MetricGrid(
      children: [
        MetricTile(
          label: l10n.depotDividendReceived12m,
          value: format.money(calendar.receivedNet12m),
          icon: Icons.payments_outlined,
          color: DepotColors.dividendBooked,
          compact: true,
        ),
        MetricTile(
          label: l10n.depotDividendReceivedYear('${calendar.today.year}'),
          value: format.money(calendar.receivedNetThisYear),
          icon: Icons.event_available_outlined,
          color: DepotColors.dividendBooked,
          compact: true,
        ),
        MetricTile(
          label: l10n.depotDividendExpected12m,
          value: '≈ ${format.money(calendar.expectedNet12m)}',
          icon: Icons.upcoming_outlined,
          color: DepotColors.dividendExpected,
          compact: true,
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
          ),
      ],
    );
  }
}
