import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../treadmill_control_colors.dart';
import '../treadmill_control_state.dart';
import '../treadmill_session.dart';
import '../../../l10n/app_localizations.dart';

class SessionHistoryDashboard extends StatelessWidget {
  const SessionHistoryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<TreadmillControlState>().pastSessions;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l10n.treadmillHistoryEmpty, textAlign: TextAlign.center),
        ),
      );
    }

    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final weekSessions = sessions.where((session) {
      return !DateTime.fromMillisecondsSinceEpoch(
        session.startTime,
      ).isBefore(weekStart);
    }).toList();
    final totalDistance = sessions.fold<double>(
      0,
      (sum, s) => sum + s.distance,
    );
    final totalDuration = sessions.fold<int>(
      0,
      (sum, s) => sum + s.elapsedTime,
    );
    final totalCalories = sessions.fold<int>(0, (sum, s) => sum + s.calories);
    final avgSpeed =
        sessions.fold<double>(0, (sum, s) => sum + s.avgSpeed) /
        sessions.length;
    final longest = sessions.reduce((a, b) => a.distance >= b.distance ? a : b);
    final fastest = sessions.reduce((a, b) => a.maxSpeed >= b.maxSpeed ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.treadmillHistoryOverview,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.treadmillHistoryOverviewSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 16),
        _MetricGrid(
          children: [
            _Metric(
              label: l10n.distance,
              value: '${totalDistance.toStringAsFixed(1)} km',
              icon: Icons.route_outlined,
              color: TreadmillColors.cyanMetric,
            ),
            _Metric(
              label: l10n.elapsedTime,
              value: _duration(totalDuration),
              icon: Icons.timer_outlined,
              color: TreadmillColors.greenMetric,
            ),
            _Metric(
              label: l10n.calories,
              value: '$totalCalories kcal',
              icon: Icons.local_fire_department_outlined,
              color: TreadmillColors.amberMetric,
            ),
            _Metric(
              label: l10n.speedLabel,
              value: '${avgSpeed.toStringAsFixed(1)} km/h',
              icon: Icons.speed_outlined,
              color: TreadmillColors.redMetric,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.treadmillHistoryLastSevenDays,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _WeeklyChart(sessions: weekSessions),
        const SizedBox(height: 24),
        Text(
          l10n.treadmillHistoryPersonalBests,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _BestCard(
          icon: Icons.workspace_premium_outlined,
          label: l10n.treadmillHistoryLongestRun,
          value: '${longest.distance.toStringAsFixed(2)} km',
          subtitle: DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(DateTime.fromMillisecondsSinceEpoch(longest.startTime)),
        ),
        const SizedBox(height: 8),
        _BestCard(
          icon: Icons.bolt_outlined,
          label: l10n.treadmillHistoryTopSpeed,
          value: '${fastest.maxSpeed.toStringAsFixed(1)} km/h',
          subtitle:
              '${l10n.treadmillHistoryAverage}: ${fastest.avgSpeed.toStringAsFixed(1)} km/h',
        ),
      ],
    );
  }
}

String _duration(int seconds) =>
    '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';

class _MetricGrid extends StatelessWidget {
  final List<_Metric> children;
  const _MetricGrid({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map(
            (child) => SizedBox(
              width: constraints.maxWidth < 500
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4,
              child: child,
            ),
          )
          .toList(),
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  const _BestCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: TreadmillColors.amberMetric),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
  );
}

class _WeeklyChart extends StatelessWidget {
  final List<TreadmillSession> sessions;
  const _WeeklyChart({required this.sessions});
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
    final distances = days
        .map(
          (day) => sessions
              .where((session) {
                final date = DateTime.fromMillisecondsSinceEpoch(
                  session.startTime,
                );
                return date.year == day.year &&
                    date.month == day.month &&
                    date.day == day.day;
              })
              .fold<double>(0, (sum, session) => sum + session.distance),
        )
        .toList();
    final maxDistance = max(1.0, distances.reduce(max));
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              7,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: max(
                              4,
                              132 * distances[index] / maxDistance,
                            ),
                            decoration: BoxDecoration(
                              color: TreadmillColors.cyanMetric.withValues(
                                alpha: distances[index] == 0 ? 0.18 : 0.85,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat.E(
                          Localizations.localeOf(context).toString(),
                        ).format(days[index]),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
