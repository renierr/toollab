import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tool_lab/l10n/app_localizations.dart';

import 'renpho_assessment.dart';
import 'renpho_body_metrics.dart';
import 'renpho_measurement.dart';

const _ink = PdfColor.fromInt(0xFF23272E);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _hairline = PdfColor.fromInt(0xFFD5D9E0);
const _weightColor = PdfColor.fromInt(0xFF8E44AD);
const _fatColor = PdfColor.fromInt(0xFFD98E00);
const _muscleColor = PdfColor.fromInt(0xFF0E9384);
const _waterColor = PdfColor.fromInt(0xFF2E86C1);
const _visceralColor = PdfColor.fromInt(0xFFC0392B);
const _goodColor = PdfColor.fromInt(0xFF2E7D32);
const _warnColor = PdfColor.fromInt(0xFFB7791F);
const _badColor = PdfColor.fromInt(0xFFC0392B);

/// One page a doctor can read without the app: what was measured, how it rates
/// against population reference ranges, where the mass sits in the body, and
/// how the week moved.
Future<Uint8List> buildRenphoReportPdf({
  required RenphoMeasurement measurement,
  required Uint8List bodyImage,
  required List<double?> weightSeries,
  required List<double?> bodyFatSeries,
  required List<double?> muscleSeries,
  required List<double?> waterSeries,
  required DateTime seriesEnd,
  required AppLocalizations l10n,
  required String locale,
}) async {
  final derived = RenphoDerived(measurement);
  final base = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/NotoSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/google_fonts/NotoSans-Bold.ttf'),
  );
  final document = pw.Document(
    theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
      defaultTextStyle: pw.TextStyle(font: base, fontSize: 9, color: _ink),
    ),
  );
  final dayLabels = [
    for (var index = 6; index >= 0; index--)
      DateFormat.E(locale).format(seriesEnd.subtract(Duration(days: index))),
  ];

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _header(measurement, l10n, locale),
          pw.SizedBox(height: 12),
          _keyValues(measurement, derived, l10n),
          pw.SizedBox(height: 12),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 4,
                  child: _section(l10n.renphoSectionSegments, [
                    pw.Image(pw.MemoryImage(bodyImage), height: 232),
                    pw.SizedBox(height: 6),
                    _segmentTable(derived, l10n),
                  ]),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  flex: 5,
                  child: _section(l10n.renphoReportAssessment, [
                    _assessmentTable(derived, l10n),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      l10n.renphoReportTrends,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    // One panel per metric: on a shared axis every curve reads
                    // as flat, since body fat and body water sit 50 points
                    // apart.
                    for (final row in [
                      [
                        (
                          l10n.renphoMetricWeight,
                          'kg',
                          _weightColor,
                          weightSeries,
                        ),
                        (
                          l10n.renphoMetricBodyFat,
                          '%',
                          _fatColor,
                          bodyFatSeries,
                        ),
                      ],
                      [
                        (
                          l10n.renphoMetricMuscle,
                          '%',
                          _muscleColor,
                          muscleSeries,
                        ),
                        (
                          l10n.renphoMetricBodyWater,
                          '%',
                          _waterColor,
                          waterSeries,
                        ),
                      ],
                    ])
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 6),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: _TrendPanel(
                                title: row.first.$1,
                                unit: row.first.$2,
                                color: row.first.$3,
                                values: row.first.$4,
                                labels: dayLabels,
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Expanded(
                              child: _TrendPanel(
                                title: row.last.$1,
                                unit: row.last.$2,
                                color: row.last.$3,
                                values: row.last.$4,
                                labels: dayLabels,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: _hairline, height: 1),
          pw.SizedBox(height: 6),
          pw.Text(
            l10n.renphoReportDisclaimer,
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
        ],
      ),
    ),
  );
  return document.save();
}

pw.Widget _header(
  RenphoMeasurement measurement,
  AppLocalizations l10n,
  String locale,
) {
  final sex = measurement.profileSex == 'male'
      ? l10n.renphoSexMale
      : l10n.renphoSexFemale;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              l10n.renphoReportTitle,
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              '${measurement.profileName} - $sex - '
              '${measurement.profileHeightCm.toStringAsFixed(1)} cm - '
              '${measurement.profileAge} ${l10n.renphoReportYears}',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            '${l10n.renphoReportMeasured}: '
            '${DateFormat.yMMMd(locale).add_Hm().format(measurement.measuredAt.toLocal())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${l10n.renphoReportGenerated}: '
            '${DateFormat.yMMMd(locale).add_Hm().format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _keyValues(
  RenphoMeasurement measurement,
  RenphoDerived derived,
  AppLocalizations l10n,
) => pw.Row(
  children: [
    for (final box in [
      (
        l10n.renphoMetricWeight,
        measurement.weightKg.toStringAsFixed(2),
        'kg',
        _weightColor,
      ),
      (l10n.renphoMetricBmi, derived.bmi.toStringAsFixed(1), '', _muted),
      (
        l10n.renphoMetricBodyFat,
        measurement.bodyFatPercent.toStringAsFixed(1),
        '%',
        _fatColor,
      ),
      (
        l10n.renphoMetricMuscle,
        measurement.musclePercent.toStringAsFixed(1),
        '%',
        _muscleColor,
      ),
      (
        l10n.renphoMetricBodyWater,
        derived.bodyWaterPercent.toStringAsFixed(1),
        '%',
        _waterColor,
      ),
      (
        l10n.renphoMetricVisceralFat,
        '${measurement.visceralFat}',
        '',
        _visceralColor,
      ),
    ])
      pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 7),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _hairline),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                box.$1,
                maxLines: 1,
                style: const pw.TextStyle(fontSize: 7, color: _muted),
              ),
              pw.SizedBox(height: 3),
              pw.RichText(
                text: pw.TextSpan(
                  text: box.$2,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: box.$4,
                  ),
                  children: [
                    pw.TextSpan(
                      text: box.$3.isEmpty ? '' : ' ${box.$3}',
                      style: const pw.TextStyle(fontSize: 8, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
  ],
);

pw.Widget _section(String title, List<pw.Widget> children) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Text(
      title,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 6),
    ...children,
  ],
);

pw.Widget _segmentTable(RenphoDerived derived, AppLocalizations l10n) =>
    pw.Table(
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: _hairline, width: .5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        _row([
          l10n.renphoSegment,
          l10n.renphoSegmentMuscle,
          l10n.renphoSegmentOfStandard,
          l10n.renphoSegmentFat,
        ], header: true),
        for (final values in derived.segments)
          _row([
            _segmentName(values.segment, l10n),
            '${values.muscleMassKg.toStringAsFixed(2)} kg',
            '${values.muscleOfStandardPercent.toStringAsFixed(0)} %',
            '${values.fatMassKg.toStringAsFixed(2)} kg',
          ]),
      ],
    );

pw.Widget _assessmentTable(RenphoDerived derived, AppLocalizations l10n) =>
    pw.Table(
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: _hairline, width: .5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2.4),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        _row([
          l10n.renphoReportMetric,
          l10n.renphoReportValue,
          l10n.renphoReportReference,
          l10n.renphoReportRating,
        ], header: true),
        for (final entry in renphoAssessment(derived))
          _row([
            _metricName(entry.metric, l10n),
            entry.value,
            entry.reference,
            _ratingName(entry.rating, l10n),
          ], ratingColor: _ratingColor(entry.rating)),
      ],
    );

pw.TableRow _row(
  List<String> cells, {
  bool header = false,
  PdfColor? ratingColor,
}) => pw.TableRow(
  children: [
    for (var index = 0; index < cells.length; index++)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        child: pw.Text(
          cells[index],
          maxLines: 1,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: header || (ratingColor != null && index == 3)
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: header
                ? _muted
                : index == 3 && ratingColor != null
                ? ratingColor
                : _ink,
          ),
        ),
      ),
  ],
);

/// One metric over the week on its own axis, so the day-to-day movement shows
/// instead of being swamped by the distance between metrics.
class _TrendPanel extends pw.StatelessWidget {
  final String title;
  final String unit;
  final PdfColor color;
  final List<double?> values;
  final List<String> labels;

  _TrendPanel({
    required this.title,
    required this.unit,
    required this.color,
    required this.values,
    required this.labels,
  });

  @override
  pw.Widget build(pw.Context context) {
    final readings = values.whereType<double>().toList();
    final decimals = unit == 'kg' ? 2 : 1;
    final lowest = readings.isEmpty ? 0.0 : readings.reduce(math.min);
    final highest = readings.isEmpty ? 1.0 : readings.reduce(math.max);
    final padding = math.max((highest - lowest) * 0.25, 0.15);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 6,
              height: 6,
              margin: const pw.EdgeInsets.only(right: 4),
              decoration: pw.BoxDecoration(
                color: color,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                title,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (readings.isNotEmpty)
              pw.Text(
                '${readings.last.toStringAsFixed(decimals)} $unit',
                style: pw.TextStyle(fontSize: 8, color: color),
              ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.SizedBox(
          height: 76,
          child: readings.length < 2
              ? pw.SizedBox()
              : pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis.fromStrings(
                      labels,
                      textStyle: const pw.TextStyle(fontSize: 6, color: _muted),
                      marginStart: 2,
                      marginEnd: 2,
                    ),
                    yAxis: pw.FixedAxis(
                      [
                        lowest - padding,
                        (lowest + highest) / 2,
                        highest + padding,
                      ],
                      format: (value) => value.toStringAsFixed(decimals),
                      textStyle: const pw.TextStyle(fontSize: 6, color: _muted),
                      divisions: true,
                      divisionsColor: _hairline,
                      divisionsWidth: .5,
                    ),
                  ),
                  datasets: [
                    pw.LineDataSet(
                      data: [
                        for (var index = 0; index < values.length; index++)
                          if (values[index] != null)
                            pw.PointChartValue(
                              index.toDouble(),
                              values[index]!,
                            ),
                      ],
                      color: color,
                      lineWidth: 1.4,
                      pointSize: 2,
                      isCurved: true,
                      drawSurface: true,
                      surfaceOpacity: .12,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

String _segmentName(RenphoSegment segment, AppLocalizations l10n) =>
    switch (segment) {
      RenphoSegment.leftArm => l10n.renphoSegmentLeftArm,
      RenphoSegment.rightArm => l10n.renphoSegmentRightArm,
      RenphoSegment.leftLeg => l10n.renphoSegmentLeftLeg,
      RenphoSegment.rightLeg => l10n.renphoSegmentRightLeg,
      RenphoSegment.trunk => l10n.renphoSegmentTrunk,
    };

String _metricName(RenphoAssessmentMetric metric, AppLocalizations l10n) =>
    switch (metric) {
      RenphoAssessmentMetric.bmi => l10n.renphoMetricBmi,
      RenphoAssessmentMetric.bodyFat => l10n.renphoMetricBodyFat,
      RenphoAssessmentMetric.visceralFat => l10n.renphoMetricVisceralFat,
      RenphoAssessmentMetric.bodyWater => l10n.renphoMetricBodyWater,
      RenphoAssessmentMetric.skeletalMuscleIndex => l10n.renphoMetricSmi,
      RenphoAssessmentMetric.segmentMuscle =>
        l10n.renphoAssessmentSegmentMuscle,
      RenphoAssessmentMetric.symmetry => l10n.renphoAssessmentSymmetry,
    };

String _ratingName(RenphoRating rating, AppLocalizations l10n) =>
    switch (rating) {
      RenphoRating.low => l10n.renphoRatingLow,
      RenphoRating.optimal => l10n.renphoRatingOptimal,
      RenphoRating.elevated => l10n.renphoRatingElevated,
      RenphoRating.high => l10n.renphoRatingHigh,
    };

PdfColor _ratingColor(RenphoRating rating) => switch (rating) {
  RenphoRating.optimal => _goodColor,
  RenphoRating.low || RenphoRating.elevated => _warnColor,
  RenphoRating.high => _badColor,
};
