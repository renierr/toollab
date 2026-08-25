import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../renpho_independent_analysis.dart';
import '../renpho_segment_labels.dart';

/// The recalculated arms, legs and trunk, next to the impedance each was
/// derived from.
class RenphoAnalysisSegmentTable extends StatelessWidget {
  final List<RenphoSegmentEstimate> estimates;

  const RenphoAnalysisSegmentTable({super.key, required this.estimates});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 40,
        columns: [
          DataColumn(label: Text(l10n.renphoSegment)),
          DataColumn(label: Text(l10n.renphoAnalysisZ50), numeric: true),
          DataColumn(label: Text(l10n.renphoAnalysisRatio), numeric: true),
          DataColumn(
            label: Text(l10n.renphoAnalysisSegmentLength),
            numeric: true,
          ),
          DataColumn(
            label: Text(l10n.renphoAnalysisSegmentLean),
            numeric: true,
          ),
          DataColumn(label: Text(l10n.renphoAnalysisSegmentFat), numeric: true),
          DataColumn(
            label: Text(l10n.renphoAnalysisVsScaleMuscle),
            numeric: true,
          ),
        ],
        rows: [
          for (final estimate in estimates)
            DataRow(
              cells: [
                DataCell(Text(estimate.segment.label(l10n))),
                DataCell(Text('${estimate.impedance50.toStringAsFixed(1)} Ω')),
                DataCell(Text(estimate.impedanceRatio.toStringAsFixed(3))),
                DataCell(Text('${estimate.lengthCm.toStringAsFixed(1)} cm')),
                DataCell(Text('${estimate.leanMassKg.toStringAsFixed(2)} kg')),
                DataCell(Text('${estimate.fatMassKg.toStringAsFixed(2)} kg')),
                DataCell(
                  Text(
                    '${estimate.leanMinusMuscleKg >= 0 ? '+' : ''}'
                    '${estimate.leanMinusMuscleKg.toStringAsFixed(2)} kg',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
