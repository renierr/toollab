import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../renpho_body_metrics.dart';
import '../renpho_colors.dart';
import '../renpho_measurement.dart';

/// The headline numbers of one scan: what the scale reported plus the figures
/// that follow from it by plain arithmetic.
class RenphoMetricsGrid extends StatelessWidget {
  final RenphoMeasurement measurement;

  const RenphoMetricsGrid({super.key, required this.measurement});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final derived = RenphoDerived(measurement);
    return MetricGrid(
      children: [
        MetricTile(
          label: l10n.renphoMetricWeight,
          value: measurement.weightKg.toStringAsFixed(2),
          unit: 'kg',
          icon: Icons.monitor_weight_outlined,
          color: RenphoColors.weight,
        ),
        MetricTile(
          label: l10n.renphoMetricBodyFat,
          value: measurement.bodyFatPercent.toStringAsFixed(1),
          unit: '%',
          icon: Icons.opacity_outlined,
          color: RenphoColors.bodyFat,
        ),
        MetricTile(
          label: l10n.renphoMetricMuscle,
          value: measurement.musclePercent.toStringAsFixed(1),
          unit: '%',
          icon: Icons.fitness_center_outlined,
          color: RenphoColors.muscle,
        ),
        MetricTile(
          label: l10n.renphoMetricBmi,
          value: derived.bmi.toStringAsFixed(1),
          icon: Icons.straighten_outlined,
          color: RenphoColors.weight,
        ),
        MetricTile(
          label: l10n.renphoMetricFatMass,
          value: derived.fatMassKg.toStringAsFixed(2),
          unit: 'kg',
          icon: Icons.pie_chart_outline,
          color: RenphoColors.bodyFat,
        ),
        MetricTile(
          label: l10n.renphoMetricFatFreeMass,
          value: derived.fatFreeMassKg.toStringAsFixed(2),
          unit: 'kg',
          icon: Icons.accessibility_new_outlined,
          color: RenphoColors.muscle,
        ),
        MetricTile(
          label: l10n.renphoMetricBodyWater,
          value: derived.bodyWaterPercent.toStringAsFixed(1),
          unit: '%',
          icon: Icons.water_drop_outlined,
          color: RenphoColors.water,
        ),
        MetricTile(
          label: l10n.renphoMetricVisceralFat,
          value: '${measurement.visceralFat}',
          icon: Icons.warning_amber_outlined,
          color: RenphoColors.visceral,
        ),
      ],
    );
  }
}
