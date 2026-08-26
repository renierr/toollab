import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/data_row.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../renpho_fluid_model.dart';
import '../renpho_independent_analysis.dart';

/// The same scan read twice: once as a dual-frequency fluid measurement, once
/// through the reconstructed 50 kHz equations, with the two put side by side.
class RenphoFluidModelCard extends StatelessWidget {
  final RenphoIndependentAnalysis analysis;
  final RenphoFluidModel model;

  const RenphoFluidModelCard({
    super.key,
    required this.analysis,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InfoCard(
      icon: Icons.water_drop_outlined,
      title: l10n.renphoAnalysisFluidModel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            label: l10n.renphoMetricExtracellularWater,
            value: '${model.extracellularWaterL.toStringAsFixed(2)} L',
          ),
          InfoRow(
            label: l10n.renphoMetricIntracellularWater,
            value: '${model.intracellularWaterL.toStringAsFixed(2)} L',
          ),
          InfoRow(
            label: l10n.renphoMetricEcwRatio,
            value:
                '${model.extracellularRatio.toStringAsFixed(3)}  '
                '(${l10n.renphoReportReference} 0.36 – 0.40)',
          ),
          InfoRow(
            label: l10n.renphoMetricResistanceZero,
            value: '${model.resistanceAtZeroHz.toStringAsFixed(1)} Ω',
          ),
          InfoRow(
            label: l10n.renphoMetricResistanceInfinity,
            value: '${model.resistanceAtInfinity.toStringAsFixed(1)} Ω',
          ),
          const SizedBox(height: 12),
          _SideBySideTable(analysis: analysis, model: model),
          const SizedBox(height: 8),
          Text(
            l10n.renphoAnalysisFluidModelHint,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SideBySideTable extends StatelessWidget {
  final RenphoIndependentAnalysis analysis;
  final RenphoFluidModel model;

  const _SideBySideTable({required this.analysis, required this.model});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <(String, double, double, String)>[
      (
        l10n.renphoMetricTotalBodyWater,
        model.totalBodyWaterL,
        analysis.totalBodyWaterL,
        'L',
      ),
      (
        l10n.renphoMetricFatFreeMass,
        model.fatFreeMassKg,
        analysis.fatFreeMassKg,
        'kg',
      ),
      (l10n.renphoMetricFatMass, model.fatMassKg, analysis.fatMassKg, 'kg'),
      (
        l10n.renphoMetricBodyFat,
        model.bodyFatPercent,
        analysis.bodyFatPercent,
        '%',
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 40,
        columns: [
          DataColumn(label: Text(l10n.renphoReportMetric)),
          DataColumn(
            label: Text(l10n.renphoAnalysisDualFrequency),
            numeric: true,
          ),
          DataColumn(
            label: Text(l10n.renphoAnalysisSingleFrequency),
            numeric: true,
          ),
          DataColumn(
            label: Text(l10n.renphoAnalysisDeltaColumn),
            numeric: true,
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(Text(row.$1)),
                DataCell(Text('${row.$2.toStringAsFixed(2)} ${row.$4}')),
                DataCell(Text('${row.$3.toStringAsFixed(2)} ${row.$4}')),
                DataCell(
                  Text(
                    '${row.$2 - row.$3 >= 0 ? '+' : ''}'
                    '${(row.$2 - row.$3).toStringAsFixed(2)} ${row.$4}',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
