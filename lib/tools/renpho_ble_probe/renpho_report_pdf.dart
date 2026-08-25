import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tool_lab/l10n/app_localizations.dart';

import 'renpho_analysis_labels.dart';
import 'renpho_assessment.dart';
import 'renpho_body_metrics.dart';
import 'renpho_independent_analysis.dart';
import 'renpho_measurement.dart';
import 'renpho_segment_labels.dart';

const _ink = PdfColor.fromInt(0xFF23272E);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _hairline = PdfColor.fromInt(0xFFD5D9E0);
const _paper = PdfColor.fromInt(0xFFF6F8FA);
const _accent = PdfColor.fromInt(0xFF1F5F8B);
const _weightColor = PdfColor.fromInt(0xFF8E44AD);
const _fatColor = PdfColor.fromInt(0xFFD98E00);
const _muscleColor = PdfColor.fromInt(0xFF0E9384);
const _waterColor = PdfColor.fromInt(0xFF2E86C1);
const _visceralColor = PdfColor.fromInt(0xFFC0392B);
const _goodColor = PdfColor.fromInt(0xFF2E7D32);
const _warnColor = PdfColor.fromInt(0xFFB7791F);
const _badColor = PdfColor.fromInt(0xFFC0392B);

/// A three-part record a doctor can read without the app: who was measured and
/// how the reading rates against population reference ranges, where the mass
/// sits in the body, and the same scan rebuilt independently from its raw
/// impedances so the two calculations can be compared.
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
  final analysis = RenphoIndependentAnalysis(derived);
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
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _runningHeader(measurement, l10n),
      footer: (context) => _footer(context, l10n),
      build: (context) => [
        _letterhead(l10n, locale),
        pw.SizedBox(height: 10),
        _recordBox(measurement, l10n, locale),
        pw.SizedBox(height: 10),
        if (analysis.usable) ...[
          _overallBanner(analysis, l10n),
          pw.SizedBox(height: 10),
        ],
        _sectionTitle(l10n.renphoReportKeyValues),
        pw.SizedBox(height: 6),
        _keyValues(measurement, derived, l10n),
        pw.SizedBox(height: 12),
        _sectionTitle(l10n.renphoReportAssessment),
        pw.SizedBox(height: 6),
        _assessmentTable(derived, l10n),
        pw.SizedBox(height: 12),
        _sectionTitle(l10n.renphoReportGuidance),
        pw.SizedBox(height: 6),
        _guidance(l10n),

        pw.NewPage(),
        _sectionTitle(l10n.renphoSectionSegments),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Image(pw.MemoryImage(bodyImage), height: 300),
            ),
            pw.SizedBox(width: 14),
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _label(l10n.renphoReportScaleModel),
                  pw.SizedBox(height: 4),
                  _segmentTable(derived, l10n),
                ],
              ),
            ),
          ],
        ),
        if (analysis.usable) ...[
          pw.SizedBox(height: 14),
          _sectionTitle(l10n.renphoAnalysisSegments),
          pw.SizedBox(height: 6),
          _analysisSegmentTable(analysis, l10n),
          pw.SizedBox(height: 5),
          _note(l10n.renphoAnalysisSegmentsHint),
          pw.SizedBox(height: 12),
          _sectionTitle(l10n.renphoAnalysisComparison),
          pw.SizedBox(height: 6),
          _comparisonTable(analysis, l10n),
          pw.SizedBox(height: 5),
          _note(l10n.renphoAnalysisComparisonHint),
        ] else ...[
          pw.SizedBox(height: 10),
          _note(l10n.renphoReportNoImpedance),
        ],

        pw.NewPage(),
        if (analysis.usable) ...[
          _sectionTitle(l10n.renphoAnalysisWholeBody),
          pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _wholeBodyTable(analysis, l10n)),
              pw.SizedBox(width: 14),
              pw.Expanded(child: _frequencyTable(analysis, l10n)),
            ],
          ),
          pw.SizedBox(height: 5),
          _note(l10n.renphoAnalysisFrequencyHint),
          pw.SizedBox(height: 12),
          _sectionTitle(l10n.renphoAnalysisFindings),
          pw.SizedBox(height: 6),
          _findingsTable(analysis, l10n),
          pw.SizedBox(height: 12),
        ],
        _sectionTitle(l10n.renphoReportTrends),
        pw.SizedBox(height: 6),
        _trends(
          l10n: l10n,
          labels: dayLabels,
          weightSeries: weightSeries,
          bodyFatSeries: bodyFatSeries,
          muscleSeries: muscleSeries,
          waterSeries: waterSeries,
        ),
        pw.SizedBox(height: 12),
        _sectionTitle(l10n.renphoReportMethodology),
        pw.SizedBox(height: 6),
        _note(l10n.renphoReportMethodologyText),
        pw.SizedBox(height: 8),
        _label(l10n.renphoReportReferences),
        pw.SizedBox(height: 4),
        for (final reference in renphoReferenceList)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '· $reference',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _letterhead(AppLocalizations l10n, String locale) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                l10n.renphoReportTitle,
                style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                  color: _accent,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                l10n.renphoReportSubtitle,
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ),
        pw.Text(
          '${l10n.renphoReportGenerated}: '
          '${DateFormat.yMMMd(locale).add_Hm().format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    ),
    pw.SizedBox(height: 6),
    pw.Container(height: 2, color: _accent),
  ],
);

pw.Widget _runningHeader(
  RenphoMeasurement measurement,
  AppLocalizations l10n,
) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Column(
    children: [
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              l10n.renphoReportTitle,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _accent,
              ),
            ),
          ),
          pw.Text(
            measurement.profileName,
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Container(height: .8, color: _hairline),
    ],
  ),
);

pw.Widget _footer(pw.Context context, AppLocalizations l10n) => pw.Column(
  children: [
    pw.Container(height: .8, color: _hairline),
    pw.SizedBox(height: 4),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            l10n.renphoReportDisclaimer,
            style: const pw.TextStyle(fontSize: 6.5, color: _muted),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Text(
          l10n.renphoReportPage(context.pageNumber, context.pagesCount),
          style: const pw.TextStyle(fontSize: 7, color: _muted),
        ),
      ],
    ),
  ],
);

/// The identification block, printed like the head of a paper record.
pw.Widget _recordBox(
  RenphoMeasurement measurement,
  AppLocalizations l10n,
  String locale,
) {
  final fields = <(String, String)>[
    (l10n.renphoProfileName, measurement.profileName),
    (
      l10n.renphoProfileSex,
      measurement.profileSex == 'male'
          ? l10n.renphoSexMale
          : l10n.renphoSexFemale,
    ),
    (
      l10n.renphoAgeAtScan,
      '${measurement.profileAge} ${l10n.renphoReportYears}',
    ),
    (
      l10n.renphoProfileHeight,
      '${measurement.profileHeightCm.toStringAsFixed(1)} cm',
    ),
    (
      l10n.renphoReportMeasured,
      DateFormat.yMMMd(
        locale,
      ).add_Hm().format(measurement.measuredAt.toLocal()),
    ),
    (
      l10n.renphoSource,
      measurement.imported
          ? l10n.renphoSourceImported
          : measurement.stored
          ? l10n.renphoSourceStored
          : l10n.renphoSourceLive,
    ),
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 9),
    decoration: pw.BoxDecoration(
      color: _paper,
      border: pw.Border.all(color: _hairline),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _label(l10n.renphoReportPerson),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            for (final field in fields)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      field.$1,
                      maxLines: 1,
                      style: const pw.TextStyle(fontSize: 6.5, color: _muted),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      field.$2,
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _overallBanner(
  RenphoIndependentAnalysis analysis,
  AppLocalizations l10n,
) {
  final color = _overallColor(analysis.overallStatus);
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 9),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          '${analysis.compositeScore}',
          style: pw.TextStyle(
            fontSize: 26,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${l10n.renphoAnalysisOverall}: '
                '${analysis.overallStatus.label(l10n)}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                l10n.renphoAnalysisSummary(
                  analysis.findingsInRange,
                  analysis.healthFindings.length,
                ),
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                l10n.renphoAnalysisScoreHint,
                style: const pw.TextStyle(fontSize: 6.5, color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String title) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: _accent,
      ),
    ),
    pw.SizedBox(height: 3),
    pw.Container(height: .8, color: _hairline),
  ],
);

pw.Widget _label(String text) => pw.Text(
  text.toUpperCase(),
  style: pw.TextStyle(
    fontSize: 7,
    fontWeight: pw.FontWeight.bold,
    color: _muted,
    letterSpacing: .6,
  ),
);

pw.Widget _note(String text) =>
    pw.Text(text, style: const pw.TextStyle(fontSize: 7, color: _muted));

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

pw.Widget _segmentTable(RenphoDerived derived, AppLocalizations l10n) => _table(
  widths: const [3, 2, 2, 2],
  header: [
    l10n.renphoSegment,
    l10n.renphoSegmentMuscle,
    l10n.renphoSegmentOfStandard,
    l10n.renphoSegmentFat,
  ],
  rows: [
    for (final values in derived.segments)
      [
        values.segment.label(l10n),
        '${values.muscleMassKg.toStringAsFixed(2)} kg',
        '${values.muscleOfStandardPercent.toStringAsFixed(0)} %',
        '${values.fatMassKg.toStringAsFixed(2)} kg',
      ],
  ],
);

pw.Widget _analysisSegmentTable(
  RenphoIndependentAnalysis analysis,
  AppLocalizations l10n,
) => _table(
  widths: const [2.6, 2, 1.8, 2, 2, 2, 2.2],
  header: [
    l10n.renphoSegment,
    l10n.renphoAnalysisZ50,
    l10n.renphoAnalysisRatio,
    l10n.renphoAnalysisSegmentLength,
    l10n.renphoAnalysisSegmentLean,
    l10n.renphoAnalysisSegmentFat,
    l10n.renphoAnalysisVsScaleMuscle,
  ],
  rows: [
    for (final estimate in analysis.segments)
      [
        estimate.segment.label(l10n),
        '${estimate.impedance50.toStringAsFixed(1)} Ω',
        estimate.impedanceRatio.toStringAsFixed(3),
        '${estimate.lengthCm.toStringAsFixed(1)} cm',
        '${estimate.leanMassKg.toStringAsFixed(2)} kg',
        '${estimate.fatMassKg.toStringAsFixed(2)} kg',
        '${estimate.leanMinusMuscleKg >= 0 ? '+' : ''}'
            '${estimate.leanMinusMuscleKg.toStringAsFixed(2)} kg',
      ],
  ],
);

pw.Widget _comparisonTable(
  RenphoIndependentAnalysis analysis,
  AppLocalizations l10n,
) => _table(
  widths: const [3.4, 2.2, 2.2, 2.6],
  header: [
    l10n.renphoReportMetric,
    l10n.renphoAnalysisScaleColumn,
    l10n.renphoAnalysisOwnColumn,
    l10n.renphoAnalysisDeltaColumn,
  ],
  rows: [
    for (final row in analysis.comparisons)
      [
        row.metric.label(l10n),
        '${row.scaleValue.toStringAsFixed(row.decimals)} ${row.unit}',
        '${row.ownValue.toStringAsFixed(row.decimals)} ${row.unit}',
        '${row.delta >= 0 ? '+' : ''}'
            '${row.delta.toStringAsFixed(row.decimals)} ${row.unit} '
            '(${row.deviationPercent.toStringAsFixed(1)} %)',
      ],
  ],
  colorLastColumn: [
    for (final row in analysis.comparisons)
      row.deviationPercent < 5
          ? _goodColor
          : row.deviationPercent < 10
          ? _warnColor
          : _badColor,
  ],
);

pw.Widget _wholeBodyTable(
  RenphoIndependentAnalysis analysis,
  AppLocalizations l10n,
) => _table(
  widths: const [3.4, 2.2],
  header: [l10n.renphoReportMetric, l10n.renphoAnalysisOwnColumn],
  rows: [
    [
      l10n.renphoMetricFatFreeMass,
      '${analysis.fatFreeMassKg.toStringAsFixed(2)} kg',
    ],
    [
      l10n.renphoMetricFatMass,
      '${analysis.fatMassKg.toStringAsFixed(2)} kg '
          '(${analysis.bodyFatPercent.toStringAsFixed(1)} %)',
    ],
    [
      l10n.renphoMetricSkeletalMuscleMass,
      '${analysis.skeletalMuscleMassKg.toStringAsFixed(2)} kg',
    ],
    [
      l10n.renphoMetricTotalBodyWater,
      '${analysis.totalBodyWaterL.toStringAsFixed(2)} L '
          '(${analysis.bodyWaterPercent.toStringAsFixed(1)} %)',
    ],
    [
      l10n.renphoMetricAppendicularLeanMass,
      '${analysis.appendicularLeanMassKg.toStringAsFixed(2)} kg',
    ],
    [
      l10n.renphoMetricAppendicularLeanIndex,
      '${analysis.appendicularLeanMassIndex.toStringAsFixed(1)} kg/m²',
    ],
    [
      l10n.renphoMetricFatFreeMassIndex,
      '${analysis.fatFreeMassIndex.toStringAsFixed(1)} kg/m²',
    ],
    [
      l10n.renphoMetricFatMassIndex,
      '${analysis.fatMassIndex.toStringAsFixed(1)} kg/m²',
    ],
  ],
);

pw.Widget _frequencyTable(
  RenphoIndependentAnalysis analysis,
  AppLocalizations l10n,
) => _table(
  widths: const [3.4, 2.2],
  header: [l10n.renphoAnalysisFrequency, 'Ω'],
  rows: [
    [
      l10n.renphoWholeBody20,
      analysis.derived.wholeBodyImpedance20.toStringAsFixed(1),
    ],
    [
      l10n.renphoAnalysisZ50Cole,
      analysis.wholeBodyImpedance50.toStringAsFixed(1),
    ],
    [
      l10n.renphoAnalysisZ50Linear,
      analysis.wholeBodyImpedance50Linear.toStringAsFixed(1),
    ],
    [
      l10n.renphoWholeBody100,
      analysis.derived.wholeBodyImpedance100.toStringAsFixed(1),
    ],
    [
      l10n.renphoImpedanceRatio,
      analysis.derived.impedanceRatio.toStringAsFixed(3),
    ],
    [
      l10n.renphoArmDifference,
      '${analysis.derived.armImpedanceDifference.toStringAsFixed(1)} Ω',
    ],
    [
      l10n.renphoLegDifference,
      '${analysis.derived.legImpedanceDifference.toStringAsFixed(1)} Ω',
    ],
  ],
);

/// The rated rows, each with the band strip that shows where in the reference
/// range the value fell.
pw.Widget _assessmentTable(RenphoDerived derived, AppLocalizations l10n) {
  final entries = renphoAssessment(derived);
  return pw.Table(
    border: pw.TableBorder.symmetric(
      inside: const pw.BorderSide(color: _hairline, width: .5),
    ),
    columnWidths: {
      0: const pw.FlexColumnWidth(3.4),
      1: const pw.FlexColumnWidth(2),
      2: const pw.FlexColumnWidth(2.4),
      3: const pw.FlexColumnWidth(3),
      4: const pw.FlexColumnWidth(1.8),
    },
    children: [
      _headerRow([
        l10n.renphoReportMetric,
        l10n.renphoReportValue,
        l10n.renphoReportReference,
        l10n.renphoReportRangePosition,
        l10n.renphoReportRating,
      ]),
      for (final entry in entries)
        pw.TableRow(
          children: [
            _textCell(entry.metric.label(l10n)),
            _textCell(entry.value, bold: true),
            _textCell(entry.reference, color: _muted),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 3,
              ),
              child: _RangeStrip(rating: entry.rating),
            ),
            _textCell(
              entry.rating.label(l10n),
              bold: true,
              color: _ratingColor(entry.rating),
            ),
          ],
        ),
    ],
  );
}

pw.Widget _findingsTable(
  RenphoIndependentAnalysis analysis,
  AppLocalizations l10n,
) => pw.Table(
  border: pw.TableBorder.symmetric(
    inside: const pw.BorderSide(color: _hairline, width: .5),
  ),
  columnWidths: {
    0: const pw.FlexColumnWidth(3.4),
    1: const pw.FlexColumnWidth(2),
    2: const pw.FlexColumnWidth(2.4),
    3: const pw.FlexColumnWidth(3),
    4: const pw.FlexColumnWidth(1.8),
  },
  children: [
    _headerRow([
      l10n.renphoReportMetric,
      l10n.renphoReportValue,
      l10n.renphoReportReference,
      l10n.renphoReportRangePosition,
      l10n.renphoReportRating,
    ]),
    for (final finding in analysis.findings)
      pw.TableRow(
        children: [
          _textCell(finding.kind.label(l10n)),
          _textCell(finding.value, bold: true),
          _textCell(finding.reference, color: _muted),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
            child: _RangeStrip(rating: finding.rating),
          ),
          _textCell(
            finding.rating.label(l10n),
            bold: true,
            color: _ratingColor(finding.rating),
          ),
        ],
      ),
  ],
);

/// What each rated value means, so the record explains itself away from the
/// app.
pw.Widget _guidance(AppLocalizations l10n) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    for (final kind in RenphoFindingKind.values)
      if (kind.guidance(l10n) case final text?)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.RichText(
            text: pw.TextSpan(
              text: '${kind.label(l10n)} — ',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
              ),
              children: [
                pw.TextSpan(
                  text: text,
                  style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                ),
              ],
            ),
          ),
        ),
  ],
);

pw.Widget _trends({
  required AppLocalizations l10n,
  required List<String> labels,
  required List<double?> weightSeries,
  required List<double?> bodyFatSeries,
  required List<double?> muscleSeries,
  required List<double?> waterSeries,
}) {
  // One panel per metric: on a shared axis every curve reads as flat, since
  // body fat and body water sit 50 points apart.
  final panels = <(String, String, PdfColor, List<double?>)>[
    (l10n.renphoMetricWeight, 'kg', _weightColor, weightSeries),
    (l10n.renphoMetricBodyFat, '%', _fatColor, bodyFatSeries),
    (l10n.renphoMetricMuscle, '%', _muscleColor, muscleSeries),
    (l10n.renphoMetricBodyWater, '%', _waterColor, waterSeries),
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      for (var row = 0; row < panels.length; row += 2)
        pw.Padding(
          padding: pw.EdgeInsets.only(top: row == 0 ? 0 : 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var column = row; column < row + 2; column++) ...[
                if (column > row) pw.SizedBox(width: 14),
                pw.Expanded(
                  child: _TrendPanel(
                    title: panels[column].$1,
                    unit: panels[column].$2,
                    color: panels[column].$3,
                    values: panels[column].$4,
                    labels: labels,
                  ),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

pw.Widget _table({
  required List<double> widths,
  required List<String> header,
  required List<List<String>> rows,
  List<PdfColor>? colorLastColumn,
}) => pw.Table(
  border: pw.TableBorder.symmetric(
    inside: const pw.BorderSide(color: _hairline, width: .5),
  ),
  columnWidths: {
    for (var index = 0; index < widths.length; index++)
      index: pw.FlexColumnWidth(widths[index]),
  },
  children: [
    _headerRow(header),
    for (var row = 0; row < rows.length; row++)
      pw.TableRow(
        children: [
          for (var cell = 0; cell < rows[row].length; cell++)
            _textCell(
              rows[row][cell],
              bold: colorLastColumn != null && cell == rows[row].length - 1,
              color: colorLastColumn != null && cell == rows[row].length - 1
                  ? colorLastColumn[row]
                  : null,
            ),
        ],
      ),
  ],
);

pw.TableRow _headerRow(List<String> cells) => pw.TableRow(
  decoration: const pw.BoxDecoration(color: _paper),
  children: [
    for (final cell in cells)
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        child: pw.Text(
          cell,
          maxLines: 1,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
          ),
        ),
      ),
  ],
);

pw.Widget _textCell(String text, {bool bold = false, PdfColor? color}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
      child: pw.Text(
        text,
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _ink,
        ),
      ),
    );

/// Four bands — low, optimal, elevated, high — with the one the value fell in
/// filled. The reference column says where the range is; this says at a glance
/// which way the value left it.
class _RangeStrip extends pw.StatelessWidget {
  final RenphoRating rating;

  _RangeStrip({required this.rating});

  @override
  pw.Widget build(pw.Context context) => pw.Row(
    children: [
      for (final band in RenphoRating.values) ...[
        pw.Expanded(
          child: pw.Container(
            height: 7,
            decoration: pw.BoxDecoration(
              color: band == rating
                  ? _ratingColor(band)
                  : PdfColor.fromInt(0xFFE9ECF1),
              borderRadius: pw.BorderRadius.circular(1.5),
            ),
          ),
        ),
        if (band != RenphoRating.values.last) pw.SizedBox(width: 2),
      ],
    ],
  );
}

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
          height: 82,
          child: readings.length < 2
              ? pw.SizedBox()
              : pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis.fromStrings(
                      labels,
                      textStyle: const pw.TextStyle(fontSize: 5, color: _muted),
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
                      textStyle: const pw.TextStyle(fontSize: 5, color: _muted),
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

PdfColor _ratingColor(RenphoRating rating) => switch (rating) {
  RenphoRating.optimal => _goodColor,
  RenphoRating.low || RenphoRating.elevated => _warnColor,
  RenphoRating.high => _badColor,
};

PdfColor _overallColor(RenphoOverallStatus status) => switch (status) {
  RenphoOverallStatus.excellent || RenphoOverallStatus.good => _goodColor,
  RenphoOverallStatus.fair => _warnColor,
  RenphoOverallStatus.attention => _badColor,
};
