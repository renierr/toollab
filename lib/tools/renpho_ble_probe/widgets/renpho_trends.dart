import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/metric_trend_chart.dart';

import '../renpho_ble_probe_state.dart';
import '../renpho_body_metrics.dart';
import '../renpho_colors.dart';

/// Seven days of body composition. Weight and body fat share one chart because
/// the interesting question is whether they move together.
class RenphoTrends extends StatelessWidget {
  const RenphoTrends({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final l10n = AppLocalizations.of(context);
    final weight = state.weeklySeries((m) => m.weightKg);
    final bodyFat = state.weeklySeries((m) => m.bodyFatPercent);
    final muscle = state.weeklySeries((m) => m.musclePercent);
    final water = state.weeklySeries((m) => RenphoDerived(m).bodyWaterPercent);
    if (weight.every((value) => value == null)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrendCard(
          title: l10n.renphoTrendWeightBodyFat,
          child: MetricTrendChart(
            values: weight,
            unit: 'kg',
            color: RenphoColors.weight,
            style: MetricTrendChartStyle.line,
            label: l10n.renphoMetricWeight,
            overlayValues: bodyFat,
            overlayUnit: '%',
            overlayColor: RenphoColors.bodyFat,
            overlayLabel: l10n.renphoMetricBodyFat,
          ),
        ),
        const SizedBox(height: 16),
        _TrendCard(
          title: l10n.renphoTrendMuscleWater,
          child: MetricTrendChart(
            values: muscle,
            unit: '%',
            color: RenphoColors.muscle,
            style: MetricTrendChartStyle.line,
            label: l10n.renphoMetricMuscle,
            overlayValues: water,
            overlayUnit: '%',
            overlayColor: RenphoColors.water,
            overlayLabel: l10n.renphoMetricBodyWater,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _TrendCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ],
  );
}
