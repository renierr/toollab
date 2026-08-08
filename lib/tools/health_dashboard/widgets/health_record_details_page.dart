import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_record.dart';
import 'health_record_header_card.dart';
import 'health_record_stats_card.dart';
import 'health_sleep_details_page.dart';
import 'health_treadmill_details_page.dart';
import 'health_workout_trend_chart.dart';

class HealthRecordDetailsPage extends StatelessWidget {
  final HealthRecord record;

  const HealthRecordDetailsPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    if (record.type == 'sleep.session') {
      return HealthSleepDetailsPage(record: record);
    }
    if (record.type == 'workout.treadmill') {
      return HealthTreadmillDetailsPage(record: record);
    }
    final l10n = AppLocalizations.of(context);
    final start = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(record.endTime);
    final titleStr =
        (record.value['title'] as String?) ??
        (record.value['exerciseType'] as String?) ??
        (record.value['dataType'] as String?) ??
        record.type;

    final heartSamples = _extractSamples(
      record.value['heartRateSamples'] ?? record.value['samples'],
    );
    final speedSamples = _extractSamples(record.value['speedSamples']);

    return Scaffold(
      appBar: AppBar(title: Text(titleStr)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HealthRecordHeaderCard(
            start: start,
            end: end,
            sourceName: record.sourceName,
          ),
          const SizedBox(height: 12),
          HealthRecordStatsCard(record: record),
          if (heartSamples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.healthDashboardHeartRate,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HealthWorkoutTrendChart(
                  values: heartSamples
                      .map((s) => s['value'] as double?)
                      .toList(),
                  unit: 'bpm',
                  color: AppTheme.accentRed,
                  style: HealthTrendChartStyle.line,
                ),
              ),
            ),
          ],
          if (speedSamples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.healthDashboardSpeed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HealthWorkoutTrendChart(
                  values: speedSamples
                      .map((s) => s['value'] as double?)
                      .toList(),
                  unit: 'km/h',
                  color: AppTheme.accentTeal,
                  style: HealthTrendChartStyle.line,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              title: Text(l10n.healthDashboardData),
              subtitle: Text(record.type),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(record.value),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractSamples(dynamic raw) {
    if (raw is! List) return const [];
    final list = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        final val =
            (item['value'] ?? item['bpm'] ?? item['speed'] ?? item['rate'])
                as num?;
        if (val != null) {
          list.add({'time': item['time'], 'value': val.toDouble()});
        }
      }
    }
    return list;
  }
}
