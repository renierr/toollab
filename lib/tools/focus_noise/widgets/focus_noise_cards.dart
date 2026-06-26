import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/responsive_orientation_layout.dart';
import '../focus_noise_breathing.dart';
import '../focus_noise_sound.dart';
import 'focus_noise_breathing_card.dart';
import 'focus_noise_sound_selector.dart';
import 'focus_noise_timer_card.dart';
import 'focus_noise_transport.dart';

class FocusNoiseCards extends StatelessWidget {
  const FocusNoiseCards({
    super.key,
    required this.statusText,
    required this.selectedSound,
    required this.isPlaying,
    required this.volume,
    required this.timerTarget,
    required this.timerLabel,
    required this.customMinutes,
    required this.breathingMode,
    required this.breathingActive,
    required this.breathingStepLabel,
    required this.breathingScale,
    required this.breathingAnimDuration,
    required this.onSelectSound,
    required this.onVolumeChanged,
    required this.onTogglePlay,
    required this.onCustomMinutesDecrement,
    required this.onCustomMinutesIncrement,
    required this.onSetPresetMinutes,
    required this.onSetCustomTimer,
    required this.onCancelTimer,
    required this.onBreathingModeChanged,
    required this.onToggleBreathing,
  });

  final String statusText;
  final FocusNoiseSound selectedSound;
  final bool isPlaying;
  final double volume;
  final DateTime? timerTarget;
  final String timerLabel;
  final int customMinutes;
  final FocusBreathingMode breathingMode;
  final bool breathingActive;
  final String breathingStepLabel;
  final double breathingScale;
  final Duration breathingAnimDuration;
  final ValueChanged<FocusNoiseSound> onSelectSound;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onTogglePlay;
  final VoidCallback onCustomMinutesDecrement;
  final VoidCallback onCustomMinutesIncrement;
  final ValueChanged<int> onSetPresetMinutes;
  final VoidCallback onSetCustomTimer;
  final VoidCallback onCancelTimer;
  final ValueChanged<FocusBreathingMode> onBreathingModeChanged;
  final VoidCallback onToggleBreathing;

  List<Widget> _buildCards() {
    return [
      FocusNoiseSoundSelector(
        sounds: FocusNoiseCatalog.sounds,
        selectedSoundId: selectedSound.id,
        onSelected: onSelectSound,
      ),
      const SizedBox(height: 12),
      FocusNoiseTransport(
        isPlaying: isPlaying,
        statusText: statusText,
        volume: volume,
        onVolumeChanged: onVolumeChanged,
        onTogglePlay: onTogglePlay,
      ),
      const SizedBox(height: 12),
      FocusNoiseTimerCard(
        isPlaying: isPlaying,
        hasTimer: timerTarget != null,
        timerLabel: timerLabel,
        customMinutes: customMinutes,
        onCustomMinutesDecrement: onCustomMinutesDecrement,
        onCustomMinutesIncrement: onCustomMinutesIncrement,
        onSetPresetMinutes: onSetPresetMinutes,
        onSetCustomTimer: onSetCustomTimer,
        onCancelTimer: onCancelTimer,
      ),
      const SizedBox(height: 12),
      FocusNoiseBreathingCard(
        patterns: FocusBreathingCatalog.patterns,
        selectedMode: breathingMode,
        active: breathingActive,
        stepText: breathingStepLabel,
        circleScale: breathingScale,
        animationDuration: breathingAnimDuration,
        onModeChanged: onBreathingModeChanged,
        onToggle: onToggleBreathing,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards();
    return ResponsiveOrientationLayout(
      portrait: Column(children: cards),
      landscape: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: cards.take(2).toList())),
          const SizedBox(width: 16),
          Expanded(child: Column(children: cards.skip(2).toList())),
        ],
      ),
    );
  }
}
