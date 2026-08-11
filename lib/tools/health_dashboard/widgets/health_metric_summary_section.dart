import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../health_value_format.dart';

class HealthMetricSummarySection extends StatelessWidget {
  final String title;
  final String type;
  final String valueKey;
  final String unit;
  final Color color;
  final bool sum;
  final bool workoutMetric;

  const HealthMetricSummarySection({
    super.key,
    required this.title,
    required this.type,
    required this.valueKey,
    required this.unit,
    required this.color,
    required this.sum,
    required this.workoutMetric,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final weeklyValues =
        (workoutMetric
                ? state.workoutMetricValues(valueKey)
                : state.weeklyMetricValues(type, valueKey, sum: sum))
            .whereType<double>()
            .toList();

    final selectedDayRecords = workoutMetric
        ? state.workoutRecordsOnDay(state.selectedDay)
        : state.recordsOnDay(type, state.selectedDay);

    final selectedValues = selectedDayRecords
        .map((r) => state.metricValue(r, valueKey))
        .whereType<double>()
        .toList();

    final double? selectedDayVal = selectedValues.isEmpty
        ? null
        : (sum
              ? selectedValues.reduce((a, b) => a + b)
              : selectedValues.reduce((a, b) => a + b) / selectedValues.length);

    final double? totalOrAvg = weeklyValues.isEmpty
        ? null
        : (sum
              ? weeklyValues.reduce((a, b) => a + b)
              : weeklyValues.reduce((a, b) => a + b) / weeklyValues.length);

    final rangeValues = [
      for (var index = 0; index < 7; index++)
        for (final record
            in workoutMetric
                ? state.workoutRecordsOnDay(state.trendDayAt(index))
                : state.recordsOnDay(type, state.trendDayAt(index)))
          ...<double?>[state.metricValue(record, valueKey)].whereType<double>(),
    ];

    final double? minVal = rangeValues.isEmpty
        ? null
        : rangeValues.reduce(math.min);
    final double? maxVal = rangeValues.isEmpty
        ? null
        : rangeValues.reduce(math.max);

    String format(double? val) {
      if (val == null) return '--';
      if (unit == 'min') {
        final duration = Duration(minutes: val.round());
        final h = duration.inHours;
        final m = duration.inMinutes.remainder(60);
        return h > 0 ? '${h}h ${m}m' : '${m}m';
      }
      return healthValue(val, unit);
    }

    final dateStr = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(state.selectedDay);

    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _SummaryStatItem(
              label: dateStr,
              value: format(selectedDayVal),
              color: color,
            ),
            _SummaryStatItem(
              label: sum
                  ? l10n.healthDashboardSevenDayTotal
                  : l10n.healthDashboardSevenDayAvg,
              value: format(totalOrAvg),
            ),
            if (minVal != null)
              _SummaryStatItem(
                label: l10n.healthDashboardSevenDayMin,
                value: format(minVal),
              ),
            if (maxVal != null)
              _SummaryStatItem(
                label: l10n.healthDashboardSevenDayMax,
                value: format(maxVal),
              ),
          ],
        ),
      ),
    );
  }
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
