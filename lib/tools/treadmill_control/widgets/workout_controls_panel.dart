import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../treadmill_control_state.dart';
import '../treadmill_control_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'workout_action_button.dart';

class WorkoutControlsPanel extends StatelessWidget {
  final bool isLandscape;

  const WorkoutControlsPanel({super.key, required this.isLandscape});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (state.workoutStatus == WorkoutStatus.inactive ||
                state.workoutStatus == WorkoutStatus.stopped)
              WorkoutActionButton(
                color: TreadmillColors.greenMetric,
                icon: Icons.play_arrow,
                label: l10n.workoutStart,
                minWidth: 120,
                onPressed: () => state.startWorkout(),
              )
            else ...[
              if (state.workoutStatus == WorkoutStatus.running)
                WorkoutActionButton(
                  color: Colors.amber,
                  icon: Icons.pause,
                  label: l10n.workoutPause,
                  onPressed: () => state.pauseWorkout(),
                )
              else if (state.workoutStatus == WorkoutStatus.paused)
                WorkoutActionButton(
                  color: TreadmillColors.greenMetric,
                  icon: Icons.play_arrow,
                  label: l10n.workoutResume,
                  onPressed: () => state.startWorkout(),
                ),
              const SizedBox(width: 8),
              WorkoutActionButton(
                color: Colors.red,
                icon: Icons.stop,
                label: l10n.workoutStop,
                onPressed: () => state.stopWorkout(),
              ),
            ],
          ],
        ),
        if (state.speedControlSupported &&
            (state.workoutStatus == WorkoutStatus.running ||
                state.workoutStatus == WorkoutStatus.paused ||
                state.workoutStatus == WorkoutStatus.starting)) ...[
          const SizedBox(height: 16),
          Text(
            l10n.speedLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => state.adjustSpeed(-0.5),
              ),
              const SizedBox(width: 16),
              Text(
                '${state.speed.toStringAsFixed(1)} km/h',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => state.adjustSpeed(0.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [2.0, 4.0, 6.0, 8.0, 10.0].map((s) {
              return ChoiceChip(
                label: Text('${s.toInt()}'),
                selected: (state.speed - s).abs() < 0.1,
                onSelected: (_) => state.adjustSpeed(s - state.speed),
              );
            }).toList(),
          ),
        ],
        if (state.inclineControlSupported &&
            (state.workoutStatus == WorkoutStatus.running ||
                state.workoutStatus == WorkoutStatus.paused ||
                state.workoutStatus == WorkoutStatus.starting)) ...[
          const SizedBox(height: 16),
          Text(
            l10n.inclineLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => state.adjustIncline(-0.5),
              ),
              const SizedBox(width: 16),
              Text(
                '${state.incline.toStringAsFixed(1)} %',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => state.adjustIncline(0.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [0.0, 2.0, 4.0, 6.0, 8.0].map((inc) {
              return ChoiceChip(
                label: Text('${inc.toInt()}%'),
                selected: (state.incline - inc).abs() < 0.1,
                onSelected: (_) => state.adjustIncline(inc - state.incline),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
