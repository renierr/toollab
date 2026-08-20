import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../renpho_body_geometry.dart';
import '../renpho_body_metrics.dart';
import '../renpho_colors.dart';
import '../renpho_segment_labels.dart';

/// Everything the eight-electrode model yields for one body part.
class RenphoSegmentDetail extends StatelessWidget {
  final RenphoSegmentValues values;

  const RenphoSegmentDetail({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = RenphoBodyGeometry.tint(values.muscleOfStandardPercent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              values.segment.label(l10n),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MetricGrid(
          wideColumns: 3,
          children: [
            MetricTile(
              compact: true,
              label: l10n.renphoSegmentMuscle,
              value: values.muscleMassKg.toStringAsFixed(2),
              unit: 'kg',
              icon: Icons.fitness_center_outlined,
              color: RenphoColors.muscle,
            ),
            MetricTile(
              compact: true,
              label: l10n.renphoSegmentMuscleOfStandard,
              value: values.muscleOfStandardPercent.toStringAsFixed(0),
              unit: '%',
              icon: Icons.speed_outlined,
              color: color,
            ),
            MetricTile(
              compact: true,
              label: l10n.renphoSegmentFat,
              value: values.fatMassKg.toStringAsFixed(2),
              unit: 'kg',
              icon: Icons.opacity_outlined,
              color: RenphoColors.bodyFat,
            ),
            MetricTile(
              compact: true,
              label: l10n.renphoSegmentFatOfStandard,
              value: values.fatOfStandardPercent.toStringAsFixed(0),
              unit: '%',
              icon: Icons.pie_chart_outline,
              color: RenphoColors.bodyFat,
            ),
            MetricTile(
              compact: true,
              label: '20 kHz',
              value: values.impedance20.toStringAsFixed(1),
              unit: 'Ω',
              icon: Icons.electric_bolt_outlined,
              color: RenphoColors.water,
            ),
            MetricTile(
              compact: true,
              label: '100 kHz',
              value: values.impedance100.toStringAsFixed(1),
              unit: 'Ω',
              icon: Icons.electric_bolt_outlined,
              color: RenphoColors.weight,
            ),
          ],
        ),
      ],
    );
  }
}
