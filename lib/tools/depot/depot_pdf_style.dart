import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tool_lab/l10n/app_localizations.dart';

/// Colors, fonts and small building blocks shared by the depot PDFs.
abstract final class DepotPdfStyle {
  static const ink = PdfColor.fromInt(0xFF23272E);
  static const muted = PdfColor.fromInt(0xFF6B7280);
  static const hairline = PdfColor.fromInt(0xFFD5D9E0);
  static const paper = PdfColor.fromInt(0xFFF6F8FA);
  static const grid = PdfColor.fromInt(0xFFE6E9EE);
  static const accent = PdfColor.fromInt(0xFF1F5F8B);
  // Darker than the app's status colors, which are tuned for dark screens.
  static const gain = PdfColor.fromInt(0xFF2E7D32);
  static const loss = PdfColor.fromInt(0xFFC0392B);

  static final PdfPageFormat pageFormat = PdfPageFormat.a4.copyWith(
    marginLeft: 28,
    marginRight: 28,
    marginTop: 26,
    marginBottom: 24,
  );

  static Future<pw.Document> document() async {
    final base = pw.Font.ttf(
      await rootBundle.load('assets/google_fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/google_fonts/NotoSans-Bold.ttf'),
    );
    return pw.Document(
      theme: pw.ThemeData.withFont(base: base, bold: bold).copyWith(
        defaultTextStyle: pw.TextStyle(font: base, fontSize: 8, color: ink),
      ),
    );
  }

  /// [c] at [alpha] over white, so tints print the same on every viewer.
  static PdfColor tint(PdfColor c, double alpha) => PdfColor(
    1 - (1 - c.red) * alpha,
    1 - (1 - c.green) * alpha,
    1 - (1 - c.blue) * alpha,
  );

  static PdfColor signColor(double? value) => value == null || value == 0
      ? ink
      : value > 0
      ? gain
      : loss;

  static pw.Widget sectionTitle(String text) => pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: muted,
      letterSpacing: .6,
    ),
  );

  static pw.Widget text(
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

  /// Label, value and value color per field, [perRow] to a row.
  static pw.Widget kpiBox(
    List<(String, String, PdfColor)> fields, {
    int perRow = 4,
  }) {
    pw.Widget field((String, String, PdfColor)? entry) => pw.Expanded(
      child: entry == null
          ? pw.SizedBox()
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entry.$1,
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 6.5, color: muted),
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
        color: paper,
        border: pw.Border.all(color: hairline),
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

  static pw.Widget footer(
    pw.Context context,
    AppLocalizations l10n,
    String disclaimer,
  ) => pw.Column(
    children: [
      pw.Container(height: .8, color: hairline),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              disclaimer,
              style: const pw.TextStyle(fontSize: 6.5, color: muted),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            l10n.depotReportPage(context.pageNumber, context.pagesCount),
            style: const pw.TextStyle(fontSize: 7, color: muted),
          ),
        ],
      ),
    ],
  );
}
