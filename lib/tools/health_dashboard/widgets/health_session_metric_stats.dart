import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'package:tool_lab/helpers/health_value_format.dart';
import '../store/health_metric_catalog.dart';
import 'health_record_stat_item.dart';
import 'health_session_overlay.dart';

/// Average, min, max and sample count of one overlay's curve during a session.
///
/// Every curve that can be laid over the timeline gets the same card, so the
/// numbers behind a line are readable without tracing it. The card carries the
/// curve's own colour rather than green-low/amber-high: a low heart rate is
/// good and a low oxygen saturation is not, so the arrows say direction only.
class HealthSessionMetricStats extends StatelessWidget {
  final HealthSessionOverlay overlay;

  /// A night reads as "night avg", a workout as "average" - the caller names
  /// the window it is showing.
  final String averageLabel;
  final String minimumLabel;
  final String maximumLabel;

  const HealthSessionMetricStats({
    super.key,
    required this.overlay,
    required this.averageLabel,
    required this.minimumLabel,
    required this.maximumLabel,
  });

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
                  label: averageLabel,
                  value: healthValue(average, overlay.unit),
                ),
                HealthRecordStatItem(
                  icon: Icons.arrow_downward_rounded,
                  color: overlay.color,
                  label: minimumLabel,
                  value: healthValue(values.reduce(math.min), overlay.unit),
                ),
                HealthRecordStatItem(
                  icon: Icons.arrow_upward_rounded,
                  color: overlay.color,
                  label: maximumLabel,
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
    HealthMetrics.speed => Icons.speed_rounded,
    HealthMetrics.cadence => Icons.rotate_right_rounded,
    HealthMetrics.power => Icons.bolt_rounded,
    _ => Icons.favorite_outline_rounded,
  };
}
