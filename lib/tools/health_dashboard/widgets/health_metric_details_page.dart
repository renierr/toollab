import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import 'health_day_navigation.dart';
import 'health_metric_history.dart';
import 'health_metric_summary_section.dart';
import 'health_metric_day_chart.dart';
import 'health_record_details_page.dart';
import 'health_workout_trend_chart.dart';

class HealthMetricDetailsPage extends StatelessWidget {
  final String title;
  final String type;
  final String valueKey;
  final String unit;
  final Color color;
  final bool sum;
  final bool workoutMetric;

  const HealthMetricDetailsPage({
    super.key,
    required this.title,
    required this.type,
    required this.valueKey,
    required this.unit,
    required this.color,
    this.sum = false,
    this.workoutMetric = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: HealthDayNavigation(),
          ),
          HealthMetricSummarySection(
            title: title,
            type: type,
            valueKey: valueKey,
            unit: unit,
            color: color,
            sum: sum,
            workoutMetric: workoutMetric,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.healthDashboardLastSevenDays,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!workoutMetric) ...[
            HealthMetricDaySection(
              type: type,
              valueKey: valueKey,
              unit: unit,
              color: color,
              day: state.selectedDay,
              sum: sum,
            ),
          ],
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HealthWorkoutTrendChart(
                values: workoutMetric
                    ? state.workoutMetricValues(valueKey)
                    : state.weeklyMetricValues(type, valueKey, sum: sum),
                unit: unit,
                color: color,
                style:
                    unit == 'kg' ||
                        unit == '%' ||
                        unit == 'ms' ||
                        unit == 'bpm' ||
                        unit == 'rpm'
                    ? HealthTrendChartStyle.line
                    : HealthTrendChartStyle.bars,
                endDate: state.trendWeekEnd,
                onDayTap: (index) => _openDayRecord(context, state, index),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.healthDashboardHistory,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          HealthMetricHistory(
            type: type,
            valueKey: valueKey,
            unit: unit,
            isNap: state.isNap,
          ),
        ],
      ),
    );
  }

  void _openDayRecord(
    BuildContext context,
    HealthDashboardState state,
    int index,
  ) {
    final day = state.trendDayAt(index);
    state.selectDay(day);
    final record = state.metricRecordOnDay(
      type: type,
      key: valueKey,
      day: day,
      workoutMetric: workoutMetric,
    );
    if (record == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthRecordDetailsPage(record: record),
      ),
    );
  }
}
