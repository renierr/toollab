import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bar chart drawn into the exported session-history PDF. A `pw` widget, so it
/// lives outside `widgets/` — it never enters the Flutter tree.
class SessionPdfBarChart extends pw.StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final PdfColor color;
  final String unit;

  SessionPdfBarChart({
    required this.labels,
    required this.values,
    required this.color,
    required this.unit,
  });

  @override
  pw.Widget build(pw.Context context) {
    final maxValue = max(1.0, values.reduce(max));
    return pw.SizedBox(
      height: 150,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: List.generate(
          values.length,
          (index) => pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    '${values[index].toStringAsFixed(unit == 'bpm' ? 0 : 1)} $unit',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    height: max(3, 100 * values[index] / maxValue),
                    decoration: pw.BoxDecoration(
                      color: color,
                      borderRadius: const pw.BorderRadius.vertical(
                        top: pw.Radius.circular(3),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    labels[index],
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
