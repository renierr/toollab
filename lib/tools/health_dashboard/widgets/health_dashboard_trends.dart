import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_dashboard_state.dart';
import 'package:tool_lab/widgets/metric_trend_chart.dart';

class HealthDashboardTrends extends StatelessWidget {
  const HealthDashboardTrends({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    final hasDistance = state.weeklyDistanceKm.any((value) => value > 0);
    final hasPulse = state.weeklyHeartRate.any((value) => value != null);
    final weightValues = state.weeklyMetricValues('body.weight', 'kilograms');
    final hasWeight = weightValues.any((value) => value != null);
    final hrvValues = state.weeklyMetricValues(
      'health.heart_rate_variability_rmssd',
      'rmssdMs',
    );
    final hasHrv = hrvValues.any((value) => value != null);
    final spO2Values = state.weeklyMetricValues(
      'health.oxygen_saturation',
      'percent',
    );
    final hasSpO2 = spO2Values.any((value) => value != null);
    final respValues = state.weeklyMetricValues(
      'health.respiratory_rate',
      'respiratoryRate',
    );
    final hasResp = respValues.any((value) => value != null);
    final bodyFatValues = state.weeklyMetricValues(
      'health.body_fat_percentage',
      'percent',
    );
    final hasBodyFat = bodyFatValues.any((value) => value != null);

    if (!hasDistance &&
        !hasPulse &&
        !hasWeight &&
        !hasHrv &&
        !hasSpO2 &&
        !hasResp &&
        !hasBodyFat) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        if (hasDistance || hasPulse)
          _DistancePulseTrend(
            distance: state.weeklyDistanceKm,
            pulse: state.weeklyHeartRate,
            endDate: state.trendWeekEnd,
          ),
        if (hasWeight || hasBodyFat)
          _WeightBodyFatTrend(
            weight: weightValues,
            bodyFat: bodyFatValues,
            endDate: state.trendWeekEnd,
          ),
        if (hasHrv)
          _MetricTrendChart(
            title: l10n.healthDashboardHrvTrend,
            values: hrvValues,
            unit: 'ms',
            color: AppTheme.accentPurple,
            style: MetricTrendChartStyle.line,
            endDate: state.trendWeekEnd,
          ),
        if (hasSpO2)
          _MetricTrendChart(
            title: l10n.healthDashboardOxygenSaturationTrend,
            values: spO2Values,
            unit: '%',
            color: AppTheme.accentBlue,
            style: MetricTrendChartStyle.line,
            endDate: state.trendWeekEnd,
          ),
        if (hasResp)
          _MetricTrendChart(
            title: l10n.healthDashboardRespiratoryRateTrend,
            values: respValues,
            unit: 'rpm',
            color: AppTheme.accentTeal,
            style: MetricTrendChartStyle.line,
            endDate: state.trendWeekEnd,
          ),
      ],
    );
  }
}

class _WeightBodyFatTrend extends StatelessWidget {
  final List<double?> weight;
  final List<double?> bodyFat;
  final DateTime endDate;

  const _WeightBodyFatTrend({
    required this.weight,
    required this.bodyFat,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text(
        AppLocalizations.of(context).healthDashboardWeightBodyFatTrend,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MetricTrendChart(
            values: weight,
            unit: 'kg',
            color: AppTheme.accentPurple,
            style: MetricTrendChartStyle.line,
            overlayValues: bodyFat,
            overlayUnit: '%',
            overlayColor: AppTheme.accentAmber,
            label: AppLocalizations.of(context).healthDashboardWeight,
            overlayLabel: AppLocalizations.of(context).healthDashboardBodyFat,
            endDate: endDate,
          ),
        ),
      ),
    ],
  );
}

class _DistancePulseTrend extends StatelessWidget {
  final List<double?> distance;
  final List<double?> pulse;
  final DateTime endDate;

  const _DistancePulseTrend({
    required this.distance,
    required this.pulse,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(
        AppLocalizations.of(context).healthDashboardWorkoutTrend,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MetricTrendChart(
            values: distance,
            unit: 'km',
            color: AppTheme.accentTeal,
            overlayValues: pulse,
            overlayUnit: 'bpm',
            overlayColor: AppTheme.accentRed,
            label: AppLocalizations.of(context).healthDashboardDistance,
            overlayLabel: AppLocalizations.of(context).healthDashboardHeartRate,
            endDate: endDate,
          ),
        ),
      ),
    ],
  );
}

class _MetricTrendChart extends StatelessWidget {
  final String title;
  final List<double?> values;
  final String unit;
  final Color color;
  final MetricTrendChartStyle style;
  final DateTime endDate;

  const _MetricTrendChart({
    required this.title,
    required this.values,
    required this.unit,
    required this.color,
    required this.style,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MetricTrendChart(
            values: values,
            unit: unit,
            color: color,
            style: style,
            endDate: endDate,
          ),
        ),
      ),
    ],
  );
}
