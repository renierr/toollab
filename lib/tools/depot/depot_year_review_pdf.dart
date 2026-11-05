import 'dart:typed_data';

import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'depot_format.dart';
import 'depot_pdf_style.dart';
import 'depot_portfolio_state.dart';
import 'depot_return_index.dart';
import 'dividends/depot_dividend_changes.dart';
import 'models/depot_capital_flow.dart';
import 'models/depot_dividend.dart';
import 'models/depot_holding.dart';
import 'models/depot_monthly_returns.dart';
import 'models/depot_summary.dart';
import 'models/depot_tax_year.dart';
import 'models/depot_transaction.dart';
import 'models/depot_year_report.dart';

typedef _S = DepotPdfStyle;

/// One page on one calendar year of the selected portfolio: value, return,
/// months, deepest fall, dividends, trading and taxes. Holding returns, the
/// allowance and dividend changes exist for the running year only.
class DepotYearReviewPdf {
  DepotYearReviewPdf._();

  /// Years the stored Max chart covers, newest first.
  static List<int> yearsOf(DepotPortfolioState state) => [
    for (final y in state.monthlyReturns.years) y.year,
  ];

  /// Reads [state] before the first await, like the overview report.
  static Future<Uint8List> build({
    required DepotPortfolioState state,
    required Map<String, DepotDividendAsset> dividendAssets,
    required int year,
    required AppLocalizations l10n,
    required String locale,
  }) async {
    final review = _Review.of(state, dividendAssets, year, l10n, locale);
    final document = await DepotPdfStyle.document();
    final format = DepotPdfStyle.pageFormat;
    const gap = 16.0;
    final half = (format.availableWidth - gap) / 2;

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        footer: (context) =>
            DepotPdfStyle.footer(context, l10n, l10n.depotYearReviewDisclaimer),
        build: (context) => [
          _header(review),
          pw.SizedBox(height: 10),
          _kpis(review),
          pw.SizedBox(height: 14),
          if (review.returns case final returns?) ...[
            _S.sectionTitle(l10n.depotYearReviewMonths),
            pw.SizedBox(height: 4),
            _months(review, returns),
            pw.SizedBox(height: 6),
          ],
          if (review.deepest case final deepest?)
            _S.text(
              l10n.depotYearReviewDeepest(
                review.format.percent(deepest.depth),
                review.day(deepest.peak),
                review.day(deepest.low),
              ),
            ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: half, child: _left(review)),
              pw.SizedBox(width: gap),
              pw.SizedBox(width: half, child: _right(review)),
            ],
          ),
        ],
      ),
    );
    return document.save();
  }
}

typedef _Mover = ({DepotHolding holding, double percent, double gain});

class _Review {
  _Review({
    required this.l10n,
    required this.locale,
    required this.format,
    required this.year,
    required this.scopeName,
    required this.until,
    required this.startValue,
    required this.endValue,
    required this.flow,
    required this.returns,
    required this.deepest,
    required this.best,
    required this.worst,
    required this.dividends,
    required this.dividendCount,
    required this.changes,
    required this.buys,
    required this.bought,
    required this.sells,
    required this.sold,
    required this.report,
    required this.tax,
    required this.allowance,
  });

  factory _Review.of(
    DepotPortfolioState state,
    Map<String, DepotDividendAsset> assets,
    int year,
    AppLocalizations l10n,
    String locale,
  ) {
    final chart = state.maxChart;
    final running = year == DateTime.now().year;
    DepotChartPoint? start;
    DepotChartPoint? end;
    var startIndex = -1;
    var endIndex = -1;
    for (var i = 0; i < chart.length; i++) {
      final y = chart[i].date.year;
      if (y < year) {
        start = chart[i];
        startIndex = i;
      } else if (y == year) {
        end = chart[i];
        endIndex = i;
      }
    }

    ({double depth, DateTime peak, DateTime low})? deepest;
    if (endIndex >= 0) {
      final index = depotReturnIndex(chart);
      final from = startIndex >= 0 ? startIndex : endIndex;
      var peak = from;
      for (var i = from; i <= endIndex; i++) {
        if (i < 0 || i >= index.length) break;
        if (index[i] > index[peak]) peak = i;
        final depth = (index[i] / index[peak] - 1) * 100;
        if (depth < (deepest?.depth ?? -0.5)) {
          deepest = (depth: depth, peak: chart[peak].date, low: chart[i].date);
        }
      }
    }

    final movers = <_Mover>[];
    if (running) {
      for (final h in state.holdings) {
        final perf = state.ytdPerformance[h.key];
        final percent = perf?.returnPercent;
        if (perf == null || percent == null || perf.gain == 0) continue;
        movers.add((holding: h, percent: percent, gain: perf.gain));
      }
      movers.sort((a, b) => b.percent.compareTo(a.percent));
    }

    var dividends = 0.0, bought = 0.0, sold = 0.0;
    var dividendCount = 0, buys = 0, sells = 0;
    for (final t in state.transactions) {
      if (t.datetime.year != year) continue;
      switch (t.type) {
        case DepotTransactionType.dividend:
          dividends += t.amountNet;
          dividendCount++;
        case DepotTransactionType.buy:
          bought += t.amount;
          buys++;
        case DepotTransactionType.sell:
          sold += t.amount;
          sells++;
        default:
          break;
      }
    }

    final currency = state.currency.trim().toUpperCase();
    final report = state.yearReports
        .where((r) => r.year == year)
        .expand((r) => r.currencies)
        .where((c) => c.currency == currency)
        .firstOrNull;

    return _Review(
      l10n: l10n,
      locale: locale,
      format: DepotFormat(locale, state.currency),
      year: year,
      scopeName:
          state.portfolios
              .where((p) => p.id == state.scope)
              .firstOrNull
              ?.name ??
          l10n.depotAllPortfolios,
      until: end?.date,
      startValue: start?.value ?? 0,
      endValue: end?.value ?? 0,
      flow: DepotCapitalFlow.years(
        chart,
        state.transactions,
      ).where((f) => f.year == year).firstOrNull,
      returns: state.monthlyReturns.years
          .where((r) => r.year == year)
          .firstOrNull,
      deepest: deepest,
      best: movers.take(5).toList(),
      worst: movers.reversed.where((m) => m.percent < 0).take(5).toList(),
      dividends: dividends,
      dividendCount: dividendCount,
      changes: running
          ? DepotDividendChanges.of(
              year: year,
              holdings: state.holdings,
              assets: assets,
            )
          : const [],
      buys: buys,
      bought: bought,
      sells: sells,
      sold: sold,
      report: report,
      tax: running ? state.taxYear(year) : null,
      allowance: state.taxAllowance,
    );
  }

  final AppLocalizations l10n;
  final String locale;
  final DepotFormat format;
  final int year;
  final String scopeName;
  final DateTime? until;
  final double startValue;
  final double endValue;
  final DepotCapitalFlow? flow;
  final DepotYearReturns? returns;
  final ({double depth, DateTime peak, DateTime low})? deepest;
  final List<_Mover> best;
  final List<_Mover> worst;
  final double dividends;
  final int dividendCount;
  final List<DepotDividendChange> changes;
  final int buys;
  final double bought;
  final int sells;
  final double sold;
  final DepotYearCurrencyReport? report;
  final DepotTaxYear? tax;
  final double allowance;

  String day(DateTime date) => DateFormat.yMd(locale).format(date);
}

pw.Widget _header(_Review r) {
  final l10n = r.l10n;
  final until = r.until;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              l10n.depotYearReviewTitle('${r.year}'),
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              [
                r.scopeName,
                if (until != null) l10n.depotYearReviewUntil(r.day(until)),
              ].join(' · '),
              style: const pw.TextStyle(fontSize: 10, color: _S.ink),
            ),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            l10n.toolNameDepot,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _S.accent,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            l10n.depotReportCreated(FormatHelper.dateTime(DateTime.now())),
            style: const pw.TextStyle(fontSize: 7, color: _S.muted),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _kpis(_Review r) {
  final l10n = r.l10n;
  final f = r.format;
  final flow = r.flow;
  final total = r.returns?.total;
  return _S.kpiBox([
    (l10n.depotYearReviewStart, f.money(r.startValue), _S.ink),
    (l10n.depotYearReviewEnd, f.money(r.endValue), _S.ink),
    if (total != null)
      (l10n.depotYearReviewReturn, f.percent(total), _S.signColor(total)),
    (l10n.depotFlowDividends, f.money(r.dividends), _S.ink),
    if (flow != null) ...[
      (l10n.depotFlowNewMoney, f.money(flow.newMoney, signed: true), _S.ink),
      (
        l10n.depotFlowMarket,
        f.money(flow.marketGain, signed: true),
        _S.signColor(flow.marketGain),
      ),
    ],
    if (r.report case final report?) ...[
      (
        l10n.depotKpiRealized,
        f.money(report.realizedGain, signed: true),
        _S.signColor(report.realizedGain),
      ),
      (l10n.depotKpiCosts, f.money(report.taxes + report.fees), _S.ink),
    ],
  ]);
}

pw.Widget _months(_Review r, DepotYearReturns returns) {
  final initial = DateFormat('MMMMM', r.locale);
  final number = NumberFormat('+0.0;-0.0', r.locale);
  return pw.Row(
    children: [
      for (var m = 0; m < 12; m++)
        pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 1),
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            decoration: pw.BoxDecoration(
              color: switch (returns.months[m]) {
                final v? => _S.tint(
                  v < 0 ? _S.loss : _S.gain,
                  (0.15 + 0.6 * (v.abs() / 8).clamp(0, 1)).toDouble(),
                ),
                null => _S.paper,
              },
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  initial.format(DateTime(2000, m + 1)),
                  style: const pw.TextStyle(fontSize: 6, color: _S.muted),
                ),
                pw.Text(switch (returns.months[m]) {
                  final v? => number.format(v),
                  null => '',
                }, style: const pw.TextStyle(fontSize: 7)),
              ],
            ),
          ),
        ),
    ],
  );
}

pw.Widget _block(String title, List<pw.Widget> rows) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    _S.sectionTitle(title),
    pw.SizedBox(height: 3),
    ...rows,
    pw.SizedBox(height: 12),
  ],
);

pw.Widget _row(String label, String value, {PdfColor? color}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
  child: pw.Row(
    children: [
      pw.Expanded(child: _S.text(label)),
      _S.text(value, right: true, color: color),
    ],
  ),
);

List<pw.Widget> _moverRows(_Review r, List<_Mover> movers) => [
  for (final m in movers)
    _row(
      m.holding.name,
      '${r.format.percent(m.percent)} · ${r.format.money(m.gain, signed: true)}',
      color: _S.signColor(m.percent),
    ),
];

pw.Widget _left(_Review r) {
  final l10n = r.l10n;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (r.best.isNotEmpty)
        _block(l10n.depotYearReviewBest, _moverRows(r, r.best)),
      if (r.worst.isNotEmpty)
        _block(l10n.depotYearReviewWorst, _moverRows(r, r.worst)),
      _block(l10n.depotYearReviewActivity, [
        _row(l10n.depotYearReviewBuys(r.buys), r.format.money(r.bought)),
        _row(l10n.depotYearReviewSells(r.sells), r.format.money(r.sold)),
      ]),
    ],
  );
}

pw.Widget _right(_Review r) {
  final l10n = r.l10n;
  final f = r.format;
  final number = NumberFormat('#,##0.00##', r.locale);
  final tax = r.tax;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _block(l10n.depotFlowDividends, [
        _row(
          l10n.depotYearReviewPayments(r.dividendCount),
          f.money(r.dividends),
        ),
        for (final c in r.changes.take(8))
          _row(
            '${c.holding.name}  ${number.format(c.before)} → '
            '${number.format(c.now)} ${c.currency}',
            f.percent(c.percent),
            color: _S.signColor(c.percent),
          ),
      ]),
      if (r.report case final report?)
        _block(l10n.depotYearReviewTaxes, [
          _row(l10n.depotTaxPaid, f.money(report.taxes)),
          _row(l10n.depotYearReviewFees, f.money(report.fees)),
          if (tax != null) ...[
            _row(
              l10n.depotTaxAllowance,
              tax.free(r.allowance) > 0
                  ? l10n.depotTaxFree(
                      f.money(tax.free(r.allowance)),
                      f.money(r.allowance),
                    )
                  : l10n.depotYearReviewUsedUp,
            ),
            if (tax.advanceLumpTotal > 0)
              _row(
                l10n.depotTaxAdvanceLumpTitle('${r.year + 1}'),
                '${f.money(tax.advanceLumpTotal)} · '
                '${f.money(tax.advanceLumpTax)}',
              ),
          ],
        ]),
    ],
  );
}
