import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../health_record.dart';
import 'health_workout_trend_chart.dart';
import 'health_record_details_page.dart';

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
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.healthDashboardHistory,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.healthDashboardNoData),
              ),
            )
          else
            ...records.map(
              (record) => _HealthRecordTile(
                record: record,
                valueKey: valueKey,
                unit: unit,
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthRecordTile extends StatelessWidget {
  final HealthRecord record;
  final String valueKey;
  final String unit;

  const _HealthRecordTile({
    required this.record,
    required this.valueKey,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final value = record.type == 'sleep.session'
        ? Duration(
            milliseconds: record.endTime - record.startTime,
          ).inMinutes.toDouble()
        : (record.value[valueKey] as num?)?.toDouble();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history_rounded),
        title: Text(MaterialLocalizations.of(context).formatMediumDate(date)),
        subtitle: Text(
          record.sourceName ??
              AppLocalizations.of(context).healthDashboardHealthConnect,
        ),
        trailing: Text(value == null ? '-' : _format(value)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HealthRecordDetailsPage(record: record),
          ),
        ),
      ),
    );
  }

  String _format(double value) => switch (unit) {
    'kg' => '${value.toStringAsFixed(1)} kg',
    'bpm' => '${value.round()} bpm',
    'steps' => value.round().toString(),
    'min' => '${value.round()} min',
    'calories' => value.round().toString(),
    _ => value.toStringAsFixed(1),
  };
}
