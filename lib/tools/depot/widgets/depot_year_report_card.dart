import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/helpers/file_save_helper.dart';

import '../depot_format.dart';
import '../depot_portfolio_state.dart';
import '../depot_tax_export.dart';
import '../models/depot_year_report.dart';
import 'depot_info_row.dart';
import 'depot_sales_summary.dart';

/// Realized gains, income, taxes and fees of one calendar year.
class DepotYearReportCard extends StatelessWidget {
  final List<DepotYearReport> reports;
  final DepotYearReport report;

  const DepotYearReportCard({
    super.key,
    required this.reports,
    required this.report,
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

    final showCurrency =
        report.currencies.length > 1 ||
        report.unknownCurrencyCount > 0 ||
        (report.currencies.isNotEmpty &&
            report.currencies.single.currency !=
                state.currency.trim().toUpperCase());

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
                    l10n.depotYearNetLabel(l10n.depotYearTitle),
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
            if (showCurrency && report.currencies.isNotEmpty)
              Text(
                l10n.depotYearCurrenciesNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            for (final currency in report.currencies)
              _CurrencyReport(report: currency, showCurrency: showCurrency),
            if (report.unknownCurrencyCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.depotYearUnknownCurrency(report.unknownCurrencyCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            DepotSalesSummary(
              transactions: state.transactions,
              year: report.year,
            ),
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

class _CurrencyReport extends StatelessWidget {
  final DepotYearCurrencyReport report;
  final bool showCurrency;

  const _CurrencyReport({required this.report, required this.showCurrency});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = DepotFormat.of(context, report.currency);
    final rows = <(String, double)>[
      (l10n.depotYearRealized(report.sells), report.realizedGain),
      (l10n.depotKpiDividends, report.dividends),
      (l10n.depotTxInterest, report.interest),
      (l10n.depotYearIncomeTotal, report.total),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCurrency) ...[
          const SizedBox(height: 12),
          Text(report.currency, style: theme.textTheme.titleSmall),
        ],
        for (final (label, amount) in rows)
          _ReportRow(label: label, amount: amount, format: format),
        if (report.missingSaleGains > 0)
          Text(
            l10n.depotSalesMissingGain(report.missingSaleGains),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        const Divider(height: 20),
        Text(l10n.depotYearCostsSeparate, style: theme.textTheme.labelMedium),
        _ReportRow(
          label: l10n.depotYearTaxes,
          amount: report.taxes,
          format: format,
          isCost: true,
        ),
        _ReportRow(
          label: l10n.depotYearFees,
          amount: report.fees,
          format: format,
          isCost: true,
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final double amount;
  final DepotFormat format;
  final bool isCost;

  const _ReportRow({
    required this.label,
    required this.amount,
    required this.format,
    this.isCost = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DepotInfoRow(
      padding: const EdgeInsets.symmetric(vertical: 3),
      title: Text(label, style: theme.textTheme.bodyMedium),
      trailing: Text(
        format.money(amount, signed: !isCost),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isCost ? null : DepotFormat.gainColor(amount),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
