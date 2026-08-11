import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_record.dart';
import '../health_dashboard_state.dart';
import '../health_sleep_quality.dart';
import '../health_value_format.dart';
import 'health_empty_state.dart';
import 'health_record_stat_item.dart';
import 'health_sleep_quality_card.dart';
import 'health_sleep_stage_timeline.dart';
import 'health_source_badge.dart';
import 'health_day_navigation.dart';
import 'health_metric_history.dart';
import 'health_workout_trend_chart.dart';

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
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: HealthDayNavigation(),
            ),
            const SizedBox(height: 24),
            HealthEmptyState(
              icon: Icons.bedtime_off_outlined,
              title: l10n.healthDashboardNoSleepOnDay,
              message: l10n.healthDashboardNoMetricDataInWeekHint,
              buttonLabel: state.trendDayOffset == 0
                  ? null
                  : l10n.healthDashboardBackToToday,
              onPressed: state.trendDayOffset == 0
                  ? null
                  : state.resetTrendDate,
            ),
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
    final naps = state
        .recordsOnDay('sleep.session', state.selectedDay)
        .where(state.isNap)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthDashboardSleepDetails)),
      // Heart-rate curves come from the dense table by range, so they are read
      // per session instead of being filtered out of the loaded week.
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _heartRates(state, [session, ...naps]),
        builder: (context, snapshot) {
          final heartRates = snapshot.data ?? const {};
          final heartRateSamples = heartRates[session.id] ?? const [];
          return ListView(
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
                    values: state.weeklyMetricValues(
                      'sleep.session',
                      'durationMinutes',
                    ),
                    unit: 'min',
                    color: Colors.indigo,
                    style: HealthTrendChartStyle.bars,
                    endDate: state.trendWeekEnd,
                    onDayTap: (index) =>
                        state.selectDay(state.trendDayAt(index)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
              if (SleepQuality.from(
                    stages: stages,
                    startTime: session.startTime,
                    endTime: session.endTime,
                    asleepMinutes: (session.value['asleepMinutes'] as num?)
                        ?.toInt(),
                  )
                  case final quality?) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.healthDashboardSleepQuality,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                HealthSleepQualityCard(quality: quality),
              ],
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
              if (_heartRateStats(heartRateSamples) case final hr?) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.healthDashboardHeartRate,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        HealthRecordStatItem(
                          icon: Icons.favorite_outline_rounded,
                          color: AppTheme.accentRed,
                          label: l10n.healthDashboardSevenDayAvg,
                          value: healthValue(hr.average, 'bpm'),
                        ),
                        HealthRecordStatItem(
                          icon: Icons.arrow_downward_rounded,
                          color: AppTheme.statusGreen,
                          label: l10n.healthDashboardSevenDayMin,
                          value: healthValue(hr.min, 'bpm'),
                        ),
                        HealthRecordStatItem(
                          icon: Icons.arrow_upward_rounded,
                          color: AppTheme.statusAmber,
                          label: l10n.healthDashboardSevenDayMax,
                          value: healthValue(hr.max, 'bpm'),
                        ),
                        HealthRecordStatItem(
                          icon: Icons.timeline_rounded,
                          color: AppTheme.accentBlue,
                          label: l10n.healthDashboardCount,
                          value: healthValue(hr.count, 'count'),
                        ),
                      ],
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
                    heartRateSamples: heartRates[nap.id] ?? const [],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.healthDashboardHistory,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              HealthMetricHistory(
                metricName: l10n.healthDashboardLastSleep,
                type: 'sleep.session',
                valueKey: 'durationMinutes',
                unit: 'min',
                isNap: state.isNap,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Min, average and max of a night's heart-rate curve. Null under two
  /// samples, where a range would be meaningless.
  static _HeartRateStats? _heartRateStats(List<Map<String, dynamic>> samples) {
    final values = [
      for (final sample in samples)
        if (sample['bpm'] case final num bpm) bpm.toDouble(),
    ];
    if (values.length < 2) return null;
    return _HeartRateStats(
      min: values.reduce(math.min),
      max: values.reduce(math.max),
      average: values.reduce((a, b) => a + b) / values.length,
      count: values.length,
    );
  }

  /// One lookup per session, keyed by record id.
  static Future<Map<String, List<Map<String, dynamic>>>> _heartRates(
    HealthDashboardState state,
    List<HealthRecord> sessions,
  ) async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final session in sessions) {
      result[session.id] = await state.heartRateSamplesDuring(session);
    }
    return result;
  }
}

class _HeartRateStats {
  final double min;
  final double max;
  final double average;
  final int count;

  const _HeartRateStats({
    required this.min,
    required this.max,
    required this.average,
    required this.count,
  });
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
