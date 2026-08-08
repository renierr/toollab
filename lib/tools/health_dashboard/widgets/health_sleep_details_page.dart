import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_record.dart';
import '../health_dashboard_state.dart';
import 'health_sleep_stage_timeline.dart';
import 'health_source_badge.dart';

class HealthSleepDetailsPage extends StatelessWidget {
  final HealthRecord record;

  const HealthSleepDetailsPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final start = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(record.endTime);
    final duration = Duration(milliseconds: record.endTime - record.startTime);
    final stages = List<Map<String, dynamic>>.from(
      (record.value['stages'] as List? ?? const []).map(
        (stage) => Map<String, dynamic>.from(stage as Map),
      ),
    );
    final heartRateSamples = context
        .watch<HealthDashboardState>()
        .heartRateSamplesDuring(record);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardSleepDetails)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 28,
                runSpacing: 16,
                children: [
                  _SleepValue(
                    label: l10n.healthDashboardSleepDuration,
                    value:
                        '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
                  ),
                  _SleepValue(
                    label: l10n.healthDashboardSleepStart,
                    value: MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(TimeOfDay.fromDateTime(start)),
                  ),
                  _SleepValue(
                    label: l10n.healthDashboardSleepEnd,
                    value: MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(TimeOfDay.fromDateTime(end)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          HealthSourceBadge(packageName: record.sourceName),
          const SizedBox(height: 24),
          if (stages.isNotEmpty) ...[
            Text(
              l10n.healthDashboardSleepStages,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _SleepLegend(hasHeartRate: heartRateSamples.length >= 2),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HealthSleepStageTimeline(
                  stages: stages,
                  heartRateSamples: heartRateSamples,
                  startTime: record.startTime,
                  endTime: record.endTime,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SleepLegend extends StatelessWidget {
  final bool hasHeartRate;

  const _SleepLegend({required this.hasHeartRate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendItem(color: Colors.amber, label: l10n.healthDashboardSleepAwake),
        _LegendItem(color: Colors.purple, label: l10n.healthDashboardSleepRem),
        _LegendItem(
          color: Colors.lightBlue,
          label: l10n.healthDashboardSleepLight,
        ),
        _LegendItem(color: Colors.indigo, label: l10n.healthDashboardSleepDeep),
        if (hasHeartRate)
          _LegendItem(
            color: Colors.redAccent,
            label: l10n.healthDashboardHeartRate,
          ),
        if (!hasHeartRate) Text(l10n.healthDashboardNoSleepHeartRate),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _SleepValue extends StatelessWidget {
  final String label;
  final String value;

  const _SleepValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
