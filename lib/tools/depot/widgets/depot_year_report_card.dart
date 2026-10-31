import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../depot_tax_export.dart';
import '../models/depot_year_report.dart';

/// Realized gains, income, taxes and fees of one calendar year.
class DepotYearReportCard extends StatelessWidget {
  final List<DepotYearReport> reports;
  final DepotYearReport report;
  final DepotFormat format;

  const DepotYearReportCard({
    super.key,
    required this.reports,
    required this.report,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.read<DepotPortfolioState>();
    // Newest first, so an older year sits at a higher index.
    final index = reports.indexOf(report);
    final older = index + 1 < reports.length ? reports[index + 1] : null;
    final newer = index > 0 ? reports[index - 1] : null;

    final rows = <(String, double)>[
      (l10n.depotYearRealized(report.sells), report.realizedGain),
      (l10n.depotKpiDividends, report.dividends),
      (l10n.depotTxInterest, report.interest),
      (l10n.depotYearIncomeTotal, report.total),
      (l10n.depotYearTaxes, -report.taxes),
      (l10n.depotYearFees, -report.fees),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.depotYearTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: l10n.depotDividendPrevYear,
                  onPressed: older == null
                      ? null
                      : () => state.setReportYear(older.year),
                ),
                Text('${report.year}', style: theme.textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: l10n.depotDividendNextYear,
                  onPressed: newer == null
                      ? null
                      : () => state.setReportYear(newer.year),
                ),
              ],
            ),
            for (final (label, amount) in rows)
              _ReportRow(label: label, amount: amount, format: format),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => FileSaveHelper.saveFile(
                  context: context,
                  suggestedName: 'depot-tax-${report.year}.csv',
                  bytes: DepotTaxExport.csv(
                    state.visibleTransactions,
                    report.year,
                  ),
                  successMessageAndroid: l10n.depotExportDone,
                  successMessageGeneralBuilder: (path) =>
                      '${l10n.depotExportDone}\n$path',
                  errorMessageBuilder: (error) =>
                      '${l10n.depotTaxExportFailed}: $error',
                ),
                icon: const Icon(Icons.download_outlined),
                label: Text(l10n.depotTaxExport),
              ),
            ),
            Text(
              l10n.depotTaxExportNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            Text(
              l10n.depotYearNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final double amount;
  final DepotFormat format;

  const _ReportRow({
    required this.label,
    required this.amount,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            format.money(amount, signed: true),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: DepotFormat.gainColor(amount),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
