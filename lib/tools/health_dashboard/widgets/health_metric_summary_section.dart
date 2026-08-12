import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../health_value_format.dart';
import '../store/health_metric_series.dart';

class HealthMetricSummarySection extends StatelessWidget {
  final HealthMetricSeries series;
  final String unit;
  final Color color;

  const HealthMetricSummarySection({
    super.key,
    required this.series,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateStr = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(context.watch<HealthDashboardState>().selectedDay);
    final min = series.min;
    final max = series.max;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _SummaryStatItem(
              label: dateStr,
              value: _format(series.selectedDayValue),
              color: color,
            ),
            _SummaryStatItem(
              label: series.sum
                  ? l10n.healthDashboardSevenDayTotal
                  : l10n.healthDashboardSevenDayAvg,
              value: _format(series.totalOrAverage),
            ),
            if (min != null)
              _SummaryStatItem(
                label: l10n.healthDashboardSevenDayMin,
                value: _format(min),
              ),
            if (max != null)
              _SummaryStatItem(
                label: l10n.healthDashboardSevenDayMax,
                value: _format(max),
              ),
          ],
        ),
      ),
    );
  }

  String _format(double? value) =>
      value == null ? '--' : healthMetricValue(value, unit);
}

class _SummaryStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryStatItem({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
