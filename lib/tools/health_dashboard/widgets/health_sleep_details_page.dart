import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_record.dart';
import '../health_dashboard_state.dart';
import 'health_sleep_stage_timeline.dart';
import 'health_source_badge.dart';
import 'health_day_navigation.dart';

class HealthSleepDetailsPage extends StatelessWidget {
  final HealthRecord record;

  const HealthSleepDetailsPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<HealthDashboardState>();
    final session = state
        .recordsOnDay('sleep.session', state.selectedDay)
        .where((candidate) => !state.isNap(candidate))
        .fold<HealthRecord?>(null, (latest, candidate) {
          if (latest == null || candidate.endTime > latest.endTime) {
            return candidate;
          }
          return latest;
        });
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.healthDashboardSleepDetails)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Align(
              alignment: Alignment.centerRight,
              child: HealthDayNavigation(),
            ),
            SizedBox(height: 24),
            Center(child: _NoSleepData()),
          ],
        ),
      );
    }
    final start = DateTime.fromMillisecondsSinceEpoch(session.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(session.endTime);
    final duration = Duration(
      milliseconds: session.endTime - session.startTime,
    );
    final stages = List<Map<String, dynamic>>.from(
      (session.value['stages'] as List? ?? const []).map(
        (stage) => Map<String, dynamic>.from(stage as Map),
      ),
    );
    final stageDurations = _stageDurations(stages);
    final stageOccurrences = _stageOccurrences(stages);
    final heartRateSamples = state.heartRateSamplesDuring(session);
    final naps = state
        .recordsOnDay('sleep.session', state.selectedDay)
        .where(state.isNap)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardSleepDetails)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: HealthDayNavigation(),
          ),
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
                  if (stageDurations['awake'] case final duration?)
                    _SleepValue(
                      label: l10n.healthDashboardSleepAwake,
                      value: l10n.healthDashboardSleepStageDuration(
                        _formatDuration(duration),
                        stageOccurrences['awake'] ?? 0,
                      ),
                      color: Colors.amber,
                    ),
                  if (stageDurations['rem'] case final duration?)
                    _SleepValue(
                      label: l10n.healthDashboardSleepRem,
                      value: l10n.healthDashboardSleepStageDuration(
                        _formatDuration(duration),
                        stageOccurrences['rem'] ?? 0,
                      ),
                      color: Colors.purple,
                    ),
                  if (stageDurations['light'] case final duration?)
                    _SleepValue(
                      label: l10n.healthDashboardSleepLight,
                      value: l10n.healthDashboardSleepStageDuration(
                        _formatDuration(duration),
                        stageOccurrences['light'] ?? 0,
                      ),
                      color: Colors.lightBlue,
                    ),
                  if (stageDurations['deep'] case final duration?)
                    _SleepValue(
                      label: l10n.healthDashboardSleepDeep,
                      value: l10n.healthDashboardSleepStageDuration(
                        _formatDuration(duration),
                        stageOccurrences['deep'] ?? 0,
                      ),
                      color: Colors.indigo,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          HealthSourceBadge(packageName: session.sourceName),
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
                  startTime: session.startTime,
                  endTime: session.endTime,
                ),
              ),
            ),
          ],
          if (naps.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.healthDashboardNaps,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...naps.map(
              (nap) => _NapDetails(
                record: nap,
                heartRateSamples: state.heartRateSamplesDuring(nap),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoSleepData extends StatelessWidget {
  const _NoSleepData();

  @override
  Widget build(BuildContext context) =>
      Text(AppLocalizations.of(context).healthDashboardNoData);
}

class _NapDetails extends StatelessWidget {
  final HealthRecord record;
  final List<Map<String, dynamic>> heartRateSamples;

  const _NapDetails({required this.record, required this.heartRateSamples});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final end = DateTime.fromMillisecondsSinceEpoch(record.endTime);
    final stages = List<Map<String, dynamic>>.from(
      (record.value['stages'] as List? ?? const []).map(
        (stage) => Map<String, dynamic>.from(stage as Map),
      ),
    );
    final duration = Duration(milliseconds: record.endTime - record.startTime);
    final time = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatDuration(duration)} · ${time.formatTimeOfDay(TimeOfDay.fromDateTime(start))} - ${time.formatTimeOfDay(TimeOfDay.fromDateTime(end))}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (stages.isNotEmpty) ...[
              const SizedBox(height: 12),
              HealthSleepStageTimeline(
                stages: stages,
                heartRateSamples: heartRateSamples,
                startTime: record.startTime,
                endTime: record.endTime,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Map<String, Duration> _stageDurations(List<Map<String, dynamic>> stages) {
  final durations = <String, Duration>{};
  for (final stage in stages) {
    final type = stage['type'] as String?;
    final start = (stage['startTime'] as num?)?.toInt();
    final end = (stage['endTime'] as num?)?.toInt();
    if (type == null || start == null || end == null || end <= start) continue;
    durations.update(
      type,
      (duration) => duration + Duration(milliseconds: end - start),
      ifAbsent: () => Duration(milliseconds: end - start),
    );
  }
  return durations;
}

Map<String, int> _stageOccurrences(List<Map<String, dynamic>> stages) {
  final occurrences = <String, int>{};
  for (final stage in stages) {
    final type = stage['type'] as String?;
    final start = (stage['startTime'] as num?)?.toInt();
    final end = (stage['endTime'] as num?)?.toInt();
    if (type == null || start == null || end == null || end <= start) continue;
    occurrences.update(type, (count) => count + 1, ifAbsent: () => 1);
  }
  return occurrences;
}

String _formatDuration(Duration duration) =>
    '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';

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
  final Color? color;

  const _SleepValue({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ],
  );
}
