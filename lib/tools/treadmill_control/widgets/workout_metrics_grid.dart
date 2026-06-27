import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../treadmill_control_state.dart';
import '../treadmill_control_colors.dart';
import '../../../../l10n/app_localizations.dart';

class WorkoutMetricsGrid extends StatelessWidget {
  final bool isLandscape;

  const WorkoutMetricsGrid({super.key, required this.isLandscape});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final l10n = AppLocalizations.of(context);

    final String speedStr = state.speed.toStringAsFixed(1);
    final String inclineStr = state.incline.toStringAsFixed(1);
    final String hrStr = state.heartRate > 0 ? '${state.heartRate}' : '--';

    final int hours = state.elapsedTime ~/ 3600;
    final int minutes = (state.elapsedTime % 3600) ~/ 60;
    final int seconds = state.elapsedTime % 60;
    final String durationStr =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final String distanceStr = state.distance.toStringAsFixed(2);
    final String caloriesStr = '${state.calories}';

    if (isLandscape) {
      return GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _MetricCard(
            label: l10n.speedLabel,
            value: speedStr,
            unit: 'km/h',
            color: TreadmillColors.cyanMetric,
            icon: Icons.speed,
            isLarge: true,
          ),
          _MetricCard(
            label: l10n.hrLabel,
            value: hrStr,
            unit: 'bpm',
            color: TreadmillColors.redMetric,
            icon: Icons.favorite,
            isLarge: true,
            pulse:
                state.heartRate > 0 &&
                state.workoutStatus == WorkoutStatus.running,
          ),
          _MetricCard(
            label: l10n.inclineLabel,
            value: inclineStr,
            unit: '%',
            color: Colors.orange,
            icon: Icons.trending_up,
          ),
          _MetricCard(
            label: l10n.elapsedTime,
            value: durationStr,
            unit: '',
            color: TreadmillColors.amberMetric,
            icon: Icons.timer,
          ),
          _MetricCard(
            label: l10n.distance,
            value: distanceStr,
            unit: 'km',
            color: Colors.green,
            icon: Icons.map,
          ),
          _MetricCard(
            label: l10n.calories,
            value: caloriesStr,
            unit: 'kcal',
            color: TreadmillColors.greenMetric,
            icon: Icons.local_fire_department,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: l10n.speedLabel,
                  value: speedStr,
                  unit: 'km/h',
                  color: TreadmillColors.cyanMetric,
                  icon: Icons.speed,
                  isLarge: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: l10n.hrLabel,
                  value: hrStr,
                  unit: 'bpm',
                  color: TreadmillColors.redMetric,
                  icon: Icons.favorite,
                  isLarge: true,
                  pulse:
                      state.heartRate > 0 &&
                      state.workoutStatus == WorkoutStatus.running,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricCard(
                label: l10n.inclineLabel,
                value: inclineStr,
                unit: '%',
                color: Colors.orange,
                icon: Icons.trending_up,
              ),
              _MetricCard(
                label: l10n.elapsedTime,
                value: durationStr,
                unit: '',
                color: TreadmillColors.amberMetric,
                icon: Icons.timer,
              ),
              _MetricCard(
                label: l10n.distance,
                value: distanceStr,
                unit: 'km',
                color: Colors.green,
                icon: Icons.map,
              ),
              _MetricCard(
                label: l10n.calories,
                value: caloriesStr,
                unit: 'kcal',
                color: TreadmillColors.greenMetric,
                icon: Icons.local_fire_department,
              ),
            ],
          ),
        ],
      );
    }
  }
}

class _MetricCard extends StatefulWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;
  final bool isLarge;
  final bool pulse;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    this.isLarge = false,
    this.pulse = false,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.pulse && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              return Transform.scale(
                scale: widget.pulse ? scale : 1.0,
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: widget.isLarge ? 28 : 22,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: widget.isLarge ? 12 : 10,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        widget.value,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: widget.isLarge ? 24 : 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.unit.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      Text(
                        widget.unit,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: widget.isLarge ? 12 : 9,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
