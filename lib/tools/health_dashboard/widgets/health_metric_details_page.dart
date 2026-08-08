import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import 'health_metric_history.dart';
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
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.healthDashboardHistory,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          HealthMetricHistory(records: records, valueKey: valueKey, unit: unit),
        ],
      ),
    );
  }
}
