import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'depot_colors.dart';
import 'depot_format.dart';
import 'depot_portfolio_labels.dart';
import 'depot_portfolio_state.dart';
import 'models/depot_filters.dart';
import 'models/depot_holding.dart';
import 'models/depot_period.dart';
import 'models/depot_summary.dart';
import 'widgets/depot_holding_avatar.dart';

const _ink = PdfColor.fromInt(0xFF23272E);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _hairline = PdfColor.fromInt(0xFFD5D9E0);
const _paper = PdfColor.fromInt(0xFFF6F8FA);
const _grid = PdfColor.fromInt(0xFFE6E9EE);
const _accent = PdfColor.fromInt(0xFF1F5F8B);
// Darker than the app's status colors, which are tuned for dark screens.
const _gainColor = PdfColor.fromInt(0xFF2E7D32);
const _lossColor = PdfColor.fromInt(0xFFC0392B);

/// Portrait report of what the overview shows: the selected portfolio and
/// period, its KPIs and charts, then the filtered holdings in their order.
class DepotReportPdf {
  DepotReportPdf._();

  /// Reads [state] before the first await, so a selection change while the
  /// fonts load cannot mix two selections.
  static Future<Uint8List> build({
    required DepotPortfolioState state,
    required Uint8List? Function(String key) logoOf,
    required AppLocalizations l10n,
    required String locale,
  }) async {
    final report = _Report.of(state, logoOf, l10n, locale);
    final base = pw.Font.ttf(
      await rootBundle.load('assets/google_fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/google_fonts/NotoSans-Bold.ttf'),
    );
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
        defaultTextStyle: pw.TextStyle(font: base, fontSize: 8, color: _ink),
      ),
    );
    final format = PdfPageFormat.a4.copyWith(
      marginLeft: 28,
      marginRight: 28,
      marginTop: 26,
      marginBottom: 24,
    );
    final width = format.availableWidth;
    const gap = 16.0;
    final leftWidth = (width - gap) * 0.58;
    final rightWidth = width - gap - leftWidth;
    final showChart = report.chart.length > 1;

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        footer: (context) => _footer(context, l10n),
        build: (context) => [
          _header(report),
          pw.SizedBox(height: 10),
          if (report.summary case final summary?) ...[
            _kpis(summary, report),
            pw.SizedBox(height: 14),
          ],
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: leftWidth,
                child: showChart
                    ? _chartSection(report, leftWidth)
                    : _moversSection(report, leftWidth),
              ),
              pw.SizedBox(width: gap),
              pw.SizedBox(width: rightWidth, child: _allocationSection(report)),
            ],
          ),
          if (showChart && report.movers.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _moversSection(report, width),
          ],
          pw.SizedBox(height: 16),
          _sectionTitle(
            l10n.depotReportHoldings(
              report.holdings.length,
              report.periodLabel,
            ),
          ),
          pw.SizedBox(height: 4),
          if (report.holdings.isEmpty)
            _text(l10n.depotHoldingsEmpty)
          else ...[
            _holdingsTable(report),
            pw.SizedBox(height: 16),
            _sectionTitle(l10n.depotReportDetails),
            pw.SizedBox(height: 4),
            _detailsTable(report),
          ],
        ],
      ),
    );
    return document.save();
  }
}

/// Everything the report shows, taken from the state in one go.
class _Report {
  _Report({
    required this.l10n,
    required this.locale,
    required this.format,
    required this.scopeName,
    required this.period,
    required this.summary,
    required this.chart,
    required this.change,
    required this.allocation,
    required this.holdings,
    required this.performance,
    required this.openValue,
    required this.filter,
    required this.syncedAt,
    required this.logos,
  });

  factory _Report.of(
    DepotPortfolioState state,
    Uint8List? Function(String key) logoOf,
    AppLocalizations l10n,
    String locale,
  ) {
    final holdings = List.of(state.visibleHoldings);
    final logos = <String, pw.ImageProvider>{};
    for (final h in holdings) {
      final key = _logoKey(h);
      final bytes = logoOf(key);
      if (bytes != null && _isPdfImage(bytes)) {
        logos[key] = pw.MemoryImage(bytes);
      }
    }
    return _Report(
      l10n: l10n,
      locale: locale,
      format: DepotFormat(locale, state.currency),
      scopeName:
          state.portfolios
              .where((p) => p.id == state.scope)
              .firstOrNull
              ?.name ??
          l10n.depotAllPortfolios,
      period: state.period,
      summary: state.summary,
      chart: List.of(state.chart),
      change: state.rangeChange,
      allocation: Map.of(state.allocation),
      holdings: holdings,
      performance: {for (final h in holdings) h: state.performanceOf(h)},
      openValue: state.openValue,
      filter: state.holdingFilter,
      syncedAt: state.lastSyncAt,
      logos: logos,
    );
  }

  final AppLocalizations l10n;
  final String locale;
  final DepotFormat format;
  final String scopeName;
  final DepotPeriod period;
  final DepotSummary? summary;
  final List<DepotChartPoint> chart;
  final DepotRangeChange? change;
  final Map<DepotHoldingKind, double> allocation;
  final List<DepotHolding> holdings;
  final Map<DepotHolding, DepotHoldingPerformance?> performance;
  final double openValue;
  final DepotHoldingFilter filter;
  final DateTime? syncedAt;
  final Map<String, pw.ImageProvider> logos;

  String get periodLabel => DepotPortfolioLabels.period(l10n, period);

  double weightOf(DepotHolding h) =>
      openValue <= 0 ? 0 : h.currentValue / openValue * 100;

  /// Up to five gains and five losses of the period, largest first.
  late final List<(DepotHolding, double)> movers = () {
    final moves = [
      for (final h in holdings)
        if (performance[h]?.gain case final gain? when gain != 0) (h, gain),
    ];
    final gains = moves.where((m) => m.$2 > 0).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final losses = moves.where((m) => m.$2 < 0).toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return [...gains.take(5), ...losses.take(5).toList().reversed];
  }();

  static String _logoKey(DepotHolding h) => h.identifier ?? h.id;

  /// The pdf package embeds PNG and JPEG only.
  static bool _isPdfImage(Uint8List b) =>
      b.length > 4 &&
      ((b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) ||
          (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF));

  pw.ImageProvider? logoOf(DepotHolding h) => logos[_logoKey(h)];
}

PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

/// [c] at [alpha] over white, so tints print the same on every viewer.
PdfColor _tint(PdfColor c, double alpha) => PdfColor(
  1 - (1 - c.red) * alpha,
  1 - (1 - c.green) * alpha,
  1 - (1 - c.blue) * alpha,
);

PdfColor _signColor(double? value) => value == null || value == 0
    ? _ink
    : value > 0
    ? _gainColor
    : _lossColor;

pw.Widget _sectionTitle(String text) => pw.Text(
  text.toUpperCase(),
  style: pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
    color: _muted,
    letterSpacing: .6,
  ),
);

pw.Widget _text(
  String s, {
  bool right = false,
  PdfColor? color,
  bool bold = false,
  double size = 7.5,
}) => pw.Text(
  s,
  maxLines: 1,
  textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
  style: pw.TextStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? pw.FontWeight.bold : null,
  ),
);

pw.Widget _dot(PdfColor color) => pw.Container(
  width: 6,
  height: 6,
  margin: const pw.EdgeInsets.only(right: 4),
  decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
);

String _filterLine(_Report r) {
  final l10n = r.l10n;
  final filter = r.filter;
  return [
    if (filter.kinds.isNotEmpty)
      [
        for (final k in DepotHoldingKind.values)
          if (filter.kinds.contains(k)) DepotPortfolioLabels.kinds(l10n, k),
      ].join(', '),
    if (filter.query.trim().isNotEmpty) '"${filter.query.trim()}"',
    if (filter.showSold) l10n.depotReportWithSold,
    l10n.depotReportSorted(DepotPortfolioLabels.sort(l10n, filter.sort)),
  ].join(' · ');
}

pw.Widget _header(_Report r) {
  final l10n = r.l10n;
  final synced = r.syncedAt;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              l10n.depotReportTitle,
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '${r.scopeName} · ${r.periodLabel}',
              style: const pw.TextStyle(fontSize: 10, color: _ink),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              _filterLine(r),
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
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
              color: _accent,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            l10n.depotReportCreated(FormatHelper.dateTime(DateTime.now())),
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
          if (synced != null)
            pw.Text(
              l10n.depotLastSync(FormatHelper.dateTime(synced)),
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
        ],
      ),
    ],
  );
}

pw.Widget _kpis(DepotSummary s, _Report r) {
  final l10n = r.l10n;
  final f = r.format;
  final fields = <(String, String, PdfColor)>[
    (l10n.depotKpiValue, f.money(s.valueEnd), _ink),
    (
      l10n.depotKpiTotalGain,
      f.money(s.totalGain, signed: true),
      _signColor(s.totalGain),
    ),
    (
      l10n.depotKpiUnrealized,
      f.percent(s.unrealizedReturn),
      _signColor(s.unrealizedReturn),
    ),
    if (s.xirr case final xirr?)
      (l10n.depotKpiXirr, f.percent(xirr), _signColor(xirr)),
    if (s.ttwror case final ttwror?)
      (l10n.depotKpiTtwror, f.percent(ttwror), _signColor(ttwror)),
    (
      l10n.depotKpiRealized,
      f.money(s.realizedGain, signed: true),
      _signColor(s.realizedGain),
    ),
    (l10n.depotKpiDividends, f.money(s.dividends), _ink),
    (l10n.depotKpiCosts, f.money(s.fees + s.taxes), _ink),
  ];
  const perRow = 4;
  pw.Widget field((String, String, PdfColor)? entry) => pw.Expanded(
    child: entry == null
        ? pw.SizedBox()
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                entry.$1,
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 6.5, color: _muted),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                entry.$2,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: entry.$3,
                ),
              ),
            ],
          ),
  );
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 7),
    decoration: pw.BoxDecoration(
      color: _paper,
      border: pw.Border.all(color: _hairline),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      children: [
        for (var i = 0; i < fields.length; i += perRow) ...[
          if (i > 0) pw.SizedBox(height: 6),
          pw.Row(
            children: [
              for (var j = i; j < i + perRow; j++)
                field(j < fields.length ? fields[j] : null),
            ],
          ),
        ],
      ],
    ),
  );
}

pw.Widget _chartSection(_Report r, double width) {
  final l10n = r.l10n;
  final change = r.change;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(l10n.depotChartTitle),
      pw.SizedBox(height: 4),
      _ValueChart(report: r, width: width),
      pw.SizedBox(height: 4),
      pw.Wrap(
        spacing: 12,
        runSpacing: 2,
        children: [
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [_dot(_accent), _text(l10n.depotChartValue, size: 7)],
          ),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [_dot(_muted), _text(l10n.depotChartInvested, size: 7)],
          ),
          if (change != null) ...[
            _text(
              '${l10n.depotChartChange} '
              '${r.format.money(change.valueChange, signed: true)}',
              size: 7,
              color: _signColor(change.valueChange),
            ),
            _text(
              '${l10n.depotChartGain} '
              '${r.format.money(change.gain, signed: true)}',
              size: 7,
              color: _signColor(change.gain),
            ),
          ],
        ],
      ),
    ],
  );
}

/// Value as a filled line, invested capital dashed, both on one money axis.
class _ValueChart extends pw.StatelessWidget {
  _ValueChart({required this.report, required this.width});

  final _Report report;
  final double width;

  static const double _height = 128;
  static const double _leftPad = 44;
  static const double _axis = 13;
  static const int _gridLines = 4;

  @override
  pw.Widget build(pw.Context context) {
    final points = report.chart;
    final values = [
      for (final p in points) ...[p.value, p.capital],
    ];
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    final pad = hi == lo ? math.max(1.0, hi.abs() * .05) : (hi - lo) * .08;
    lo -= pad;
    hi += pad;
    final t0 = points.first.date.millisecondsSinceEpoch;
    final span = math.max(1, points.last.date.millisecondsSinceEpoch - t0);
    final plotW = width - _leftPad;
    final plotH = _height - _axis - 4;

    double xOf(DateTime d) =>
        _leftPad + (d.millisecondsSinceEpoch - t0) / span * plotW;
    // Painter space: y grows upwards from the bottom edge.
    double yOf(double v) => _axis + (v - lo) / (hi - lo) * plotH;

    final dates = span > const Duration(days: 400).inMilliseconds
        ? DateFormat.yMMM(report.locale)
        : DateFormat.MMMd(report.locale);
    final labels = <pw.Widget>[];
    for (var i = 0; i < _gridLines; i++) {
      final v = lo + (hi - lo) * i / (_gridLines - 1);
      labels.add(
        pw.Positioned(
          left: 0,
          top: _height - yOf(v) - 4.5,
          child: pw.SizedBox(
            width: _leftPad - 4,
            child: _text(
              report.format.axisMoney(v),
              right: true,
              size: 6,
              color: _muted,
            ),
          ),
        ),
      );
    }
    const ticks = 4;
    for (var i = 0; i < ticks; i++) {
      final p = points[(i * (points.length - 1) / (ticks - 1)).round()];
      final x = xOf(p.date);
      labels.add(
        pw.Positioned(
          left: (x - 20).clamp(_leftPad - 4, width - 40).toDouble(),
          top: _height - _axis + 2,
          child: pw.SizedBox(
            width: 40,
            child: pw.Text(
              dates.format(p.date),
              textAlign: i == 0
                  ? pw.TextAlign.left
                  : i == ticks - 1
                  ? pw.TextAlign.right
                  : pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 6, color: _muted),
            ),
          ),
        ),
      );
    }

    return pw.SizedBox(
      width: width,
      height: _height,
      child: pw.Stack(
        overflow: pw.Overflow.visible,
        children: [
          pw.CustomPaint(
            size: PdfPoint(width, _height),
            painter: (canvas, size) {
              canvas
                ..setStrokeColor(_grid)
                ..setLineWidth(.5);
              for (var i = 0; i < _gridLines; i++) {
                final y = yOf(lo + (hi - lo) * i / (_gridLines - 1));
                canvas
                  ..moveTo(_leftPad, y)
                  ..lineTo(width, y);
              }
              canvas.strokePath();

              canvas.moveTo(xOf(points.first.date), _axis);
              for (final p in points) {
                canvas.lineTo(xOf(p.date), yOf(p.value));
              }
              canvas
                ..lineTo(xOf(points.last.date), _axis)
                ..closePath()
                ..setFillColor(_tint(_accent, .12))
                ..fillPath();

              canvas
                ..setStrokeColor(_muted)
                ..setLineWidth(.8)
                ..setLineDashPattern([3, 2])
                ..moveTo(xOf(points.first.date), yOf(points.first.capital));
              for (final p in points.skip(1)) {
                canvas.lineTo(xOf(p.date), yOf(p.capital));
              }
              canvas
                ..strokePath()
                ..setLineDashPattern();

              canvas
                ..setStrokeColor(_accent)
                ..setLineWidth(1.2)
                ..moveTo(xOf(points.first.date), yOf(points.first.value));
              for (final p in points.skip(1)) {
                canvas.lineTo(xOf(p.date), yOf(p.value));
              }
              canvas.strokePath();

              canvas
                ..setStrokeColor(_muted)
                ..setLineWidth(.6)
                ..moveTo(_leftPad, _axis)
                ..lineTo(width, _axis)
                ..strokePath();
            },
          ),
          ...labels,
        ],
      ),
    );
  }
}

pw.Widget _allocationSection(_Report r) {
  final l10n = r.l10n;
  final total = r.allocation.values.fold<double>(0, (a, v) => a + v);
  final entries = r.allocation.entries.where((e) => e.value > 0).toList();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(l10n.depotAllocationTitle),
      pw.SizedBox(height: 6),
      if (total > 0) ...[
        pw.ClipRRect(
          horizontalRadius: 3,
          verticalRadius: 3,
          child: pw.Row(
            children: [
              for (final e in entries)
                if ((e.value / total * 1000).round() > 0)
                  pw.Expanded(
                    flex: (e.value / total * 1000).round(),
                    child: pw.Container(
                      height: 9,
                      color: _pdf(DepotColors.kind(e.key)),
                    ),
                  ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        for (final e in entries)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(
              children: [
                _dot(_pdf(DepotColors.kind(e.key))),
                pw.Expanded(
                  child: _text(DepotPortfolioLabels.kinds(l10n, e.key)),
                ),
                _text(r.format.money(e.value), right: true),
                pw.SizedBox(
                  width: 42,
                  child: _text(
                    r.format.percent(e.value / total * 100, signed: false),
                    right: true,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    ],
  );
}

/// Diverging bars around a centre line: gains right, losses left.
pw.Widget _moversSection(_Report r, double width) {
  final movers = r.movers;
  if (movers.isEmpty) return pw.SizedBox();
  const nameWidth = 110.0;
  const valueWidth = 62.0;
  final half = (width - nameWidth - valueWidth - 8) / 2;
  final largest = movers.map((m) => m.$2.abs()).reduce(math.max);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(r.l10n.depotReportMovers(r.periodLabel)),
      pw.SizedBox(height: 5),
      for (final (holding, gain) in movers)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
          child: pw.Row(
            children: [
              pw.SizedBox(width: nameWidth, child: _text(holding.name)),
              pw.SizedBox(
                width: half,
                height: 9,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: gain < 0
                      ? _bar(half * gain.abs() / largest, _lossColor)
                      : pw.SizedBox(),
                ),
              ),
              pw.Container(width: .6, height: 9, color: _hairline),
              pw.SizedBox(
                width: half,
                height: 9,
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: gain > 0
                      ? _bar(half * gain / largest, _gainColor)
                      : pw.SizedBox(),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: valueWidth,
                child: _text(
                  r.format.money(gain, signed: true),
                  right: true,
                  color: _signColor(gain),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _bar(double width, PdfColor color) => pw.Container(
  width: math.max(1, width),
  height: 7,
  color: _tint(color, .75),
);

/// Logo when one is cached as PNG or JPEG, otherwise the app's initials badge.
pw.Widget _avatar(_Report r, DepotHolding h, {required bool faded}) {
  const size = 15.0;
  final logo = r.logoOf(h);
  final color = _pdf(DepotColors.holding(h.identifier ?? h.id));
  final child = logo != null
      ? pw.Container(
          width: size,
          height: size,
          padding: const pw.EdgeInsets.all(1.5),
          decoration: pw.BoxDecoration(
            color: _paper,
            borderRadius: pw.BorderRadius.circular(3.5),
          ),
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        )
      : pw.Container(
          width: size,
          height: size,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: _tint(color, .18),
            border: pw.Border.all(color: _tint(color, .6), width: .6),
            borderRadius: pw.BorderRadius.circular(3.5),
          ),
          child: pw.Text(
            DepotHoldingAvatar.initials(h.name),
            style: pw.TextStyle(
              fontSize: 5.5,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        );
  return faded ? pw.Opacity(opacity: .4, child: child) : child;
}

pw.Widget _holdingCell(_Report r, DepotHolding h) {
  final l10n = r.l10n;
  final sub = [
    h.isSold ? l10n.depotHoldingSold : DepotPortfolioLabels.kind(l10n, h.kind),
    ?h.identifier,
  ].join(' · ');
  return pw.Row(
    children: [
      _avatar(r, h, faded: h.isSold),
      pw.SizedBox(width: 5),
      pw.Flexible(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _text(h.name, bold: true, color: h.isSold ? _muted : _ink),
            _text(sub, size: 6, color: _muted),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _table({
  required List<String> headers,
  required List<List<pw.Widget>> rows,
  required Map<int, pw.TableColumnWidth> widths,
  List<pw.Widget>? total,
}) {
  pw.Widget head(String text, int i) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
    child: pw.Text(
      text,
      textAlign: i == 0 ? pw.TextAlign.left : pw.TextAlign.right,
      style: pw.TextStyle(
        fontSize: 6.5,
        fontWeight: pw.FontWeight.bold,
        color: _muted,
      ),
    ),
  );
  pw.Widget cell(pw.Widget child) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
    child: child,
  );
  return pw.Table(
    columnWidths: widths,
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _grid, width: .5),
      bottom: pw.BorderSide(color: _hairline, width: .6),
    ),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          color: _paper,
          border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
        ),
        children: [
          for (var i = 0; i < headers.length; i++) head(headers[i], i),
        ],
      ),
      for (final row in rows)
        pw.TableRow(children: [for (final c in row) cell(c)]),
      if (total != null)
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _hairline)),
          ),
          children: [for (final c in total) cell(c)],
        ),
    ],
  );
}

pw.Widget _holdingsTable(_Report r) {
  final l10n = r.l10n;
  final f = r.format;
  final maxWeight = r.holdings
      .map(r.weightOf)
      .fold<double>(0, (a, w) => math.max(a, w));
  var totalValue = 0.0;
  var totalGain = 0.0;
  var totalWeight = 0.0;
  for (final h in r.holdings) {
    totalValue += h.currentValue;
    totalGain += r.performance[h]?.gain ?? 0;
    totalWeight += r.weightOf(h);
  }
  const weightWidth = 50.0;
  return _table(
    headers: [
      l10n.depotReportColHolding,
      l10n.depotDetailShares,
      l10n.depotReportColPrice,
      l10n.depotKpiValue,
      l10n.depotDetailWeight,
      l10n.depotDetailPeriodGain(r.periodLabel),
      l10n.depotDetailPeriodReturn(r.periodLabel),
    ],
    widths: const {
      0: pw.FlexColumnWidth(),
      1: pw.FixedColumnWidth(48),
      2: pw.FixedColumnWidth(56),
      3: pw.FixedColumnWidth(64),
      4: pw.FixedColumnWidth(weightWidth),
      5: pw.FixedColumnWidth(66),
      6: pw.FixedColumnWidth(58),
    },
    rows: [
      for (final h in r.holdings)
        () {
          final perf = r.performance[h];
          final weight = r.weightOf(h);
          final muted = h.isSold ? _muted : null;
          return [
            _holdingCell(r, h),
            _text(h.shares == 0 ? '–' : f.shares(h.shares), right: true),
            _text(f.money(h.currentPrice), right: true, color: muted),
            _text(f.money(h.currentValue), right: true, color: muted),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _text(f.percent(weight, signed: false), right: true),
                pw.SizedBox(height: 1.5),
                pw.Container(
                  width: maxWeight <= 0
                      ? 0
                      : (weightWidth - 6) * weight / maxWeight,
                  height: 2,
                  color: _tint(_accent, .55),
                ),
              ],
            ),
            _text(
              perf == null ? '–' : f.money(perf.gain, signed: true),
              right: true,
              color: _signColor(perf?.gain),
            ),
            _text(
              perf?.returnPercent == null
                  ? '–'
                  : f.percent(perf!.returnPercent!),
              right: true,
              color: _signColor(perf?.returnPercent),
              bold: true,
            ),
          ];
        }(),
    ],
    total: [
      _text(l10n.depotReportTotal, bold: true),
      pw.SizedBox(),
      pw.SizedBox(),
      _text(f.money(totalValue), right: true, bold: true),
      _text(f.percent(totalWeight, signed: false), right: true, bold: true),
      _text(
        f.money(totalGain, signed: true),
        right: true,
        bold: true,
        color: _signColor(totalGain),
      ),
      pw.SizedBox(),
    ],
  );
}

pw.Widget _detailsTable(_Report r) {
  final l10n = r.l10n;
  final f = r.format;
  final day = DateFormat.yMd(r.locale);
  return _table(
    headers: [
      l10n.depotReportColHolding,
      l10n.depotDetailPurchasePrice,
      l10n.depotDetailPurchaseValue,
      l10n.depotReportColUnrealized,
      l10n.depotReportColRealized,
      l10n.depotKpiDividends,
      l10n.depotKpiCosts,
      l10n.depotKpiXirr,
      l10n.depotReportColSince,
    ],
    widths: const {
      0: pw.FlexColumnWidth(),
      1: pw.FixedColumnWidth(52),
      2: pw.FixedColumnWidth(58),
      3: pw.FixedColumnWidth(62),
      4: pw.FixedColumnWidth(54),
      5: pw.FixedColumnWidth(50),
      6: pw.FixedColumnWidth(46),
      7: pw.FixedColumnWidth(40),
      8: pw.FixedColumnWidth(44),
    },
    rows: [
      for (final h in r.holdings)
        [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _text(h.name, color: h.isSold ? _muted : _ink),
              if (h.quoteExchange case final exchange?)
                _text(exchange, size: 6, color: _muted),
            ],
          ),
          _text(
            h.purchasePrice == 0 ? '–' : f.money(h.purchasePrice),
            right: true,
          ),
          _text(f.money(h.purchaseValue), right: true),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _text(
                f.money(h.unrealizedGain, signed: true),
                right: true,
                color: _signColor(h.unrealizedGain),
              ),
              if (!h.isSold)
                _text(
                  f.percent(h.unrealizedReturn),
                  right: true,
                  size: 6,
                  color: _signColor(h.unrealizedReturn),
                ),
            ],
          ),
          _text(
            f.money(h.realizedGain, signed: true),
            right: true,
            color: _signColor(h.realizedGain),
          ),
          _text(f.money(h.dividends), right: true),
          _text(f.money(h.fees + h.taxes), right: true, color: _muted),
          _text(
            h.xirr == null ? '–' : f.percent(h.xirr!),
            right: true,
            color: _signColor(h.xirr),
          ),
          _text(
            h.earliestActivity == null ? '–' : day.format(h.earliestActivity!),
            right: true,
            color: _muted,
          ),
        ],
    ],
  );
}

pw.Widget _footer(pw.Context context, AppLocalizations l10n) => pw.Column(
  children: [
    pw.Container(height: .8, color: _hairline),
    pw.SizedBox(height: 4),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            l10n.depotReportDisclaimer,
            style: const pw.TextStyle(fontSize: 6.5, color: _muted),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          l10n.depotReportPage(context.pageNumber, context.pagesCount),
          style: const pw.TextStyle(fontSize: 7, color: _muted),
        ),
      ],
    ),
  ],
);
