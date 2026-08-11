import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_value_format.dart';
import '../store/health_metric_catalog.dart';
import 'health_record_stat_item.dart';
import 'health_sleep_stage_timeline.dart';

/// Average, min, max and sample count of one overlay's curve during a session.
///
/// Every curve that can be laid over the timeline gets the same card, so the
/// numbers behind a line are readable without tracing it. The card carries the
/// curve's own colour rather than green-low/amber-high: a low heart rate is
/// good and a low oxygen saturation is not, so the arrows say direction only.
class HealthSleepMetricStats extends StatelessWidget {
  final HealthSleepOverlay overlay;

  const HealthSleepMetricStats({super.key, required this.overlay});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = [for (final sample in overlay.samples) sample.v];
    if (values.length < 2) return const SizedBox.shrink();
    final average = values.reduce((a, b) => a + b) / values.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(overlay.label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                HealthRecordStatItem(
                  icon: _icon(overlay.key),
                  color: overlay.color,
                  label: l10n.healthDashboardNightAvg,
                  value: healthValue(average, overlay.unit),
                ),
                HealthRecordStatItem(
                  icon: Icons.arrow_downward_rounded,
                  color: overlay.color,
                  label: l10n.healthDashboardNightMin,
                  value: healthValue(values.reduce(math.min), overlay.unit),
                ),
                HealthRecordStatItem(
                  icon: Icons.arrow_upward_rounded,
                  color: overlay.color,
                  label: l10n.healthDashboardNightMax,
                  value: healthValue(values.reduce(math.max), overlay.unit),
                ),
                HealthRecordStatItem(
                  icon: Icons.timeline_rounded,
                  color: overlay.color,
                  label: l10n.healthDashboardCount,
                  value: healthValue(values.length, 'count'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static IconData _icon(String metric) => switch (metric) {
    HealthMetrics.respiratoryRate => Icons.air_rounded,
    HealthMetrics.oxygenSaturation => Icons.bubble_chart_outlined,
    HealthMetrics.hrvRmssd => Icons.monitor_heart_outlined,
    _ => Icons.favorite_outline_rounded,
  };
}
