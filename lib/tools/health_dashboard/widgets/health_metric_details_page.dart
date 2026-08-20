import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../health_dashboard_state.dart';
import '../store/health_metric_series.dart';
import '../store/health_queries.dart';
import 'health_day_navigation.dart';
import 'health_empty_state.dart';
import 'health_metric_history.dart';
import 'health_metric_summary_section.dart';
import 'health_metric_day_chart.dart';
import 'health_record_details_page.dart';
import 'package:tool_lab/widgets/metric_trend_chart.dart';

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

  bool get _isSession =>
      type == HealthQueries.workoutType || type == HealthQueries.sleepType;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<HealthMetricSeries>(
        future: HealthQueries.instance.metricSeries(
          type: type,
          valueKey: valueKey,
          days: [
            for (var index = 0; index < 7; index++) state.trendDayAt(index),
          ],
          sum: sum,
        ),
        builder: (context, snapshot) {
          final series = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: HealthDayNavigation(),
              ),
              if (series == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (series.hasData) ...[
                HealthMetricSummarySection(
                  series: series,
                  unit: unit,
                  color: color,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.healthDashboardLastSevenDays,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: MetricTrendChart(
                      values: series.values,
                      unit: unit,
                      color: color,
                      style: sum
                          ? MetricTrendChartStyle.bars
                          : MetricTrendChartStyle.line,
                      endDate: state.trendWeekEnd,
                      onDayTap: (index) =>
                          _openDayRecord(context, state, index),
                    ),
                  ),
                ),
                HealthMetricDaySection(
                  type: type,
                  valueKey: valueKey,
                  unit: unit,
                  color: color,
                  day: state.selectedDay,
                  sum: sum,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: HealthEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: l10n.healthDashboardNoMetricDataInWeek(title),
                    message: l10n.healthDashboardNoMetricDataInWeekHint,
                    // Already on today: nothing to jump back to, so the settings
                    // default is the only useful action left.
                    buttonLabel: state.trendDayOffset == 0
                        ? null
                        : l10n.healthDashboardBackToToday,
                    onPressed: state.trendDayOffset == 0
                        ? null
                        : state.resetTrendDate,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                l10n.healthDashboardHistory,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              HealthMetricHistory(
                metricName: title,
                type: type,
                valueKey: valueKey,
                unit: unit,
                isNap: state.isNap,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDayRecord(
    BuildContext context,
    HealthDashboardState state,
    int index,
  ) async {
    final day = state.trendDayAt(index);
    await state.selectDay(day);
    // A point metric has no record worth a page of its own - the day section
    // below is the drilldown, so tapping a day just moves the selection there.
    if (!_isSession) return;
    final records = await HealthQueries.instance.recordsForDay(
      type: type,
      day: day,
    );
    if (records.isEmpty || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthRecordDetailsPage(record: records.first),
      ),
    );
  }
}
