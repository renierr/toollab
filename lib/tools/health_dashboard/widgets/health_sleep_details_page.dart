import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_record.dart';
import '../health_dashboard_state.dart';
import '../store/health_metric_catalog.dart';
import '../health_sleep_quality.dart';
import 'health_empty_state.dart';
import 'health_session_metric_stats.dart';
import 'health_sleep_quality_card.dart';
import 'health_sleep_stage_breakdown.dart';
import 'health_session_overlay.dart';
import 'health_session_timeline_section.dart';
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
      body: FutureBuilder<Map<String, List<HealthSessionOverlay>>>(
        future: _overlays(state, [session, ...naps], l10n),
        builder: (context, snapshot) {
          final overlays = snapshot.data ?? const {};
          final sessionOverlays = overlays[session.id] ?? const [];
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 28,
                        runSpacing: 16,
                        children: [
                          _SleepValue(
                            label: l10n.healthDashboardSleepDuration,
                            value: _formatDuration(duration),
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
                      if (stageDurations.isNotEmpty) ...[
                        const Divider(height: 28),
                        HealthSleepStageBreakdown(
                          durations: stageDurations,
                          occurrences: stageOccurrences,
                        ),
                      ],
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
                HealthSessionTimelineSection(
                  stages: stages,
                  overlays: sessionOverlays,
                  startTime: session.startTime,
                  endTime: session.endTime,
                ),
              ],
              // Every curve gets the same card, not heart rate alone - a line
              // scaled to its own range says nothing about its values.
              for (final overlay in sessionOverlays)
                if (overlay.isDrawable) ...[
                  const SizedBox(height: 24),
                  HealthSessionMetricStats(
                    overlay: overlay,
                    averageLabel: l10n.healthDashboardNightAvg,
                    minimumLabel: l10n.healthDashboardNightMin,
                    maximumLabel: l10n.healthDashboardNightMax,
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
                    overlays: overlays[nap.id] ?? const [],
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

  /// The curves that can be laid over a night, one lookup per metric per
  /// session. A metric with too few samples still comes back - the legend shows
  /// it as unavailable rather than quietly leaving it out.
  static Future<Map<String, List<HealthSessionOverlay>>> _overlays(
    HealthDashboardState state,
    List<HealthRecord> sessions,
    AppLocalizations l10n,
  ) async {
    final specs = [
      (
        HealthMetrics.heartRate,
        l10n.healthDashboardHeartRate,
        'bpm',
        AppTheme.accentRed,
      ),
      (
        HealthMetrics.respiratoryRate,
        l10n.healthDashboardRespiratoryRate,
        'rpm',
        AppTheme.accentTeal,
      ),
      (
        HealthMetrics.oxygenSaturation,
        l10n.healthDashboardOxygenSaturation,
        '%',
        AppTheme.accentBlue,
      ),
      (
        HealthMetrics.hrvRmssd,
        l10n.healthDashboardHrv,
        'ms',
        AppTheme.accentPurple,
      ),
    ];
    final result = <String, List<HealthSessionOverlay>>{};
    for (final session in sessions) {
      result[session.id] = [
        for (final (metric, label, unit, color) in specs)
          HealthSessionOverlay(
            key: metric,
            label: label,
            unit: unit,
            color: color,
            samples: await state.metricSamplesDuring(session, metric),
          ),
      ];
    }
    return result;
  }
}

class _NapDetails extends StatelessWidget {
  final HealthRecord record;
  final List<HealthSessionOverlay> overlays;

  const _NapDetails({required this.record, required this.overlays});

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
              HealthSessionTimelineSection(
                stages: stages,
                overlays: overlays,
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
