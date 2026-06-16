import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

class FocusNoiseTimerCard extends StatelessWidget {
  final bool isPlaying;
  final bool hasTimer;
  final String timerLabel;
  final int customMinutes;
  final VoidCallback onCustomMinutesDecrement;
  final VoidCallback onCustomMinutesIncrement;
  final ValueChanged<int> onSetPresetMinutes;
  final VoidCallback onSetCustomTimer;
  final VoidCallback onCancelTimer;

  const FocusNoiseTimerCard({
    super.key,
    required this.isPlaying,
    required this.hasTimer,
    required this.timerLabel,
    required this.customMinutes,
    required this.onCustomMinutesDecrement,
    required this.onCustomMinutesIncrement,
    required this.onSetPresetMinutes,
    required this.onSetCustomTimer,
    required this.onCancelTimer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InfoCard(
      icon: Icons.timer_outlined,
      title: l10n.focusAutoStopTimer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isPlaying ? timerLabel : l10n.focusStartPlaybackToEnableTimer),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [30, 60, 120, 240].map((minutes) {
              return ActionChip(
                label: Text(
                  minutes >= 60 ? '${minutes ~/ 60}h' : '${minutes}m',
                ),
                onPressed: isPlaying ? () => onSetPresetMinutes(minutes) : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: isPlaying ? onCustomMinutesDecrement : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(child: Text(l10n.focusCustomMinutes(customMinutes))),
              IconButton(
                onPressed: isPlaying ? onCustomMinutesIncrement : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isPlaying ? onSetCustomTimer : null,
                child: Text(l10n.focusSetTimer),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: hasTimer ? onCancelTimer : null,
            child: Text(l10n.focusCancelTimer),
          ),
        ],
      ),
    );
  }
}
