import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/metric_tile.dart';

import '../renpho_ble_probe_state.dart';
import '../renpho_body_metrics.dart';
import '../renpho_colors.dart';
import '../renpho_measurement.dart';

/// The headline numbers of one scan: what the scale reported plus the figures
/// that follow from it by plain arithmetic.
class RenphoMetricsGrid extends StatelessWidget {
  final RenphoMeasurement measurement;

  /// Draws the last seven days behind each figure. Only meaningful for the
  /// latest reading — an older one would sit under a trend that ran past it.
  final bool showTrends;

  const RenphoMetricsGrid({
    super.key,
    required this.measurement,
    this.showTrends = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final derived = RenphoDerived(measurement);
    final state = showTrends ? context.watch<RenphoBleProbeState>() : null;
    List<double?>? trend(double Function(RenphoMeasurement) pick) =>
        state?.weeklySeries(pick);
    return MetricGrid(
      children: [
        MetricTile(
          label: l10n.renphoMetricWeight,
          value: measurement.weightKg.toStringAsFixed(2),
          unit: 'kg',
          icon: Icons.monitor_weight_outlined,
          color: RenphoColors.weight,
          trend: trend((m) => m.weightKg),
        ),
        MetricTile(
          label: l10n.renphoMetricBodyFat,
          value: measurement.bodyFatPercent.toStringAsFixed(1),
          unit: '%',
          icon: Icons.opacity_outlined,
          color: RenphoColors.bodyFat,
          trend: trend((m) => m.bodyFatPercent),
        ),
        MetricTile(
          label: l10n.renphoMetricMuscle,
          value: measurement.musclePercent.toStringAsFixed(1),
          unit: '%',
          icon: Icons.fitness_center_outlined,
          color: RenphoColors.muscle,
          trend: trend((m) => m.musclePercent),
        ),
        MetricTile(
          label: l10n.renphoMetricBmi,
          value: derived.bmi.toStringAsFixed(1),
          icon: Icons.straighten_outlined,
          color: RenphoColors.weight,
          trend: trend((m) => RenphoDerived(m).bmi),
        ),
        MetricTile(
          label: l10n.renphoMetricFatMass,
          value: derived.fatMassKg.toStringAsFixed(2),
          unit: 'kg',
          icon: Icons.pie_chart_outline,
          color: RenphoColors.bodyFat,
          trend: trend((m) => RenphoDerived(m).fatMassKg),
        ),
        MetricTile(
          label: l10n.renphoMetricFatFreeMass,
          value: derived.fatFreeMassKg.toStringAsFixed(2),
          unit: 'kg',
          icon: Icons.accessibility_new_outlined,
          color: RenphoColors.muscle,
          trend: trend((m) => RenphoDerived(m).fatFreeMassKg),
        ),
        MetricTile(
          label: l10n.renphoMetricBodyWater,
          value: derived.bodyWaterPercent.toStringAsFixed(1),
          unit: '%',
          icon: Icons.water_drop_outlined,
          color: RenphoColors.water,
          trend: trend((m) => RenphoDerived(m).bodyWaterPercent),
        ),
        MetricTile(
          label: l10n.renphoMetricVisceralFat,
          value: '${measurement.visceralFat}',
          icon: Icons.warning_amber_outlined,
          color: RenphoColors.visceral,
          trend: trend((m) => m.visceralFat.toDouble()),
        ),
      ],
    );
  }
}
