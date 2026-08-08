import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';

import '../health_dashboard_state.dart';
import 'health_workout_trend_chart.dart';

class HealthDashboardTrends extends StatelessWidget {
  const HealthDashboardTrends({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final hasDistance = state.weeklyDistanceKm.any((value) => value > 0);
    final hasPulse = state.weeklyHeartRate.any((value) => value != null);
    final hasWeight = state
        .weeklyMetricValues('body.weight', 'kilograms')
        .any((value) => value != null);
    if (!hasDistance && !hasPulse && !hasWeight) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        _WeekNavigation(endDate: state.trendWeekEnd),
        if (hasDistance || hasPulse)
          _DistancePulseTrend(
            distance: state.weeklyDistanceKm,
            pulse: state.weeklyHeartRate,
            endDate: state.trendWeekEnd,
          ),
        if (hasWeight)
          _WeightTrend(
            values: state.weeklyMetricValues('body.weight', 'kilograms'),
            endDate: state.trendWeekEnd,
          ),
      ],
    );
  }
}

class _WeekNavigation extends StatelessWidget {
  final DateTime endDate;

  const _WeekNavigation({required this.endDate});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HealthDashboardState>();
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.healthDashboardTrends,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: l10n.healthDashboardPreviousDay,
          onPressed: () =>
              context.read<HealthDashboardState>().previousTrendDay(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        TextButton(
          onPressed: state.trendDayOffset == 0
              ? null
              : () => context.read<HealthDashboardState>().resetTrendDate(),
          child: Text(
            MaterialLocalizations.of(context).formatMediumDate(endDate),
          ),
        ),
        IconButton(
          tooltip: l10n.healthDashboardNextDay,
          onPressed: state.trendDayOffset == 0
              ? null
              : () => context.read<HealthDashboardState>().nextTrendDay(),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
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
          child: HealthWorkoutTrendChart(
            values: distance,
            unit: 'km',
            color: AppTheme.accentTeal,
            overlayValues: pulse,
            overlayUnit: 'bpm',
            overlayColor: AppTheme.accentRed,
            endDate: endDate,
          ),
        ),
      ),
    ],
  );
}

class _WeightTrend extends StatelessWidget {
  final List<double?> values;
  final DateTime endDate;

  const _WeightTrend({required this.values, required this.endDate});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      Text(
        AppLocalizations.of(context).healthDashboardWeightTrend,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HealthWorkoutTrendChart(
            values: values,
            unit: 'kg',
            color: AppTheme.accentPurple,
            style: HealthTrendChartStyle.line,
            endDate: endDate,
          ),
        ),
      ),
    ],
  );
}
