import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../renpho_analysis_labels.dart';
import '../renpho_independent_analysis.dart';

/// Scale against recalculation, one row per metric, with the size of the gap.
class RenphoComparisonTable extends StatelessWidget {
  final List<RenphoComparison> comparisons;

  const RenphoComparisonTable({super.key, required this.comparisons});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 40,
        columns: [
          DataColumn(label: Text(l10n.renphoReportMetric)),
          DataColumn(
            label: Text(l10n.renphoAnalysisScaleColumn),
            numeric: true,
          ),
          DataColumn(label: Text(l10n.renphoAnalysisOwnColumn), numeric: true),
          DataColumn(
            label: Text(l10n.renphoAnalysisDeltaColumn),
            numeric: true,
          ),
        ],
        rows: [
          for (final row in comparisons)
            DataRow(
              cells: [
                DataCell(Text(row.metric.label(l10n))),
                DataCell(
                  Text(
                    '${row.scaleValue.toStringAsFixed(row.decimals)} ${row.unit}',
                  ),
                ),
                DataCell(
                  Text(
                    '${row.ownValue.toStringAsFixed(row.decimals)} ${row.unit}',
                  ),
                ),
                DataCell(
                  Text(
                    '${row.delta >= 0 ? '+' : ''}'
                    '${row.delta.toStringAsFixed(row.decimals)} ${row.unit}'
                    '  (${row.deviationPercent.toStringAsFixed(1)} %)',
                    style: TextStyle(
                      color: row.deviationPercent < 5
                          ? AppTheme.statusGreen
                          : row.deviationPercent < 10
                          ? AppTheme.statusAmber
                          : AppTheme.statusRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
