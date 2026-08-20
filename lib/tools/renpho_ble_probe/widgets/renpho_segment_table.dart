import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../renpho_body_metrics.dart';

/// The eight-electrode breakdown. The masses are the trustworthy column; the
/// percentages of standard divide by a reference as small as 0.64 kg, so a
/// 10 gram model error there reads as more than a percentage point.
class RenphoSegmentTable extends StatelessWidget {
  final RenphoDerived derived;

  const RenphoSegmentTable({super.key, required this.derived});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 36,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 40,
        columns: [
          DataColumn(label: Text(l10n.renphoSegment)),
          DataColumn(label: Text(l10n.renphoSegmentMuscle), numeric: true),
          DataColumn(label: Text(l10n.renphoSegmentOfStandard), numeric: true),
          DataColumn(label: Text(l10n.renphoSegmentFat), numeric: true),
          DataColumn(label: Text('20 kHz'), numeric: true),
          DataColumn(label: Text('100 kHz'), numeric: true),
        ],
        rows: [
          for (final segment in derived.segments)
            DataRow(
              cells: [
                DataCell(Text(_name(l10n, segment.segment))),
                DataCell(Text('${segment.muscleMassKg.toStringAsFixed(2)} kg')),
                DataCell(
                  Text(
                    '${segment.muscleOfStandardPercent.toStringAsFixed(0)} %',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                DataCell(Text('${segment.fatMassKg.toStringAsFixed(2)} kg')),
                DataCell(Text(segment.impedance20.toStringAsFixed(1))),
                DataCell(Text(segment.impedance100.toStringAsFixed(1))),
              ],
            ),
        ],
      ),
    );
  }

  String _name(AppLocalizations l10n, RenphoSegment segment) =>
      switch (segment) {
        RenphoSegment.leftArm => l10n.renphoSegmentLeftArm,
        RenphoSegment.rightArm => l10n.renphoSegmentRightArm,
        RenphoSegment.leftLeg => l10n.renphoSegmentLeftLeg,
        RenphoSegment.rightLeg => l10n.renphoSegmentRightLeg,
        RenphoSegment.trunk => l10n.renphoSegmentTrunk,
      };
}
