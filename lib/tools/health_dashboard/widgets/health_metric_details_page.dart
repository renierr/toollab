import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import 'health_metric_history.dart';
import 'health_day_navigation.dart';
import 'health_record_details_page.dart';
import 'health_workout_trend_chart.dart';

class HealthMetricDetailsPage extends StatelessWidget {
  final String title;
  final String type;
  final String valueKey;
  final String unit;
  final Color color;
  final bool sum;

  const HealthMetricDetailsPage({
    super.key,
    required this.title,
    required this.type,
    required this.valueKey,
    required this.unit,
    required this.color,
    this.sum = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final records = state.recordsOfType(type);
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
          Text(
            l10n.healthDashboardLastSevenDays,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HealthWorkoutTrendChart(
                values: state.weeklyMetricValues(type, valueKey, sum: sum),
                unit: unit,
                color: color,
                style: unit == 'kg' || unit == 'bpm' || unit == 'calories'
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
            records: records,
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
    final records = state.recordsOnDay(type, day);
    if (records.isEmpty) return;
    state.selectDay(day);
    final record = records.reduce(
      (latest, candidate) =>
          candidate.endTime > latest.endTime ? candidate : latest,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthRecordDetailsPage(record: record),
      ),
    );
  }
}
