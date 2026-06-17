import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../focus_noise_breathing.dart';

class FocusNoiseBreathingCard extends StatelessWidget {
  final List<FocusBreathingPattern> patterns;
  final FocusBreathingMode selectedMode;
  final bool active;
  final String stepText;
  final double circleScale;
  final Duration animationDuration;
  final ValueChanged<FocusBreathingMode> onModeChanged;
  final VoidCallback onToggle;

  const FocusNoiseBreathingCard({
    super.key,
    required this.patterns,
    required this.selectedMode,
    required this.active,
    required this.stepText,
    required this.circleScale,
    required this.animationDuration,
    required this.onModeChanged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InfoCard(
      icon: Icons.air,
      title: l10n.focusBreathingGuide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: patterns.map((pattern) {
              return ChoiceChip(
                selected: pattern.mode == selectedMode,
                label: Text(pattern.label),
                onSelected: (_) => onModeChanged(pattern.mode),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          width: 3,
                        ),
                      ),
                    ),
                    AnimatedScale(
                      duration: animationDuration,
                      scale: circleScale,
                      curve: Curves.linear,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          stepText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onToggle,
            icon: Icon(active ? Icons.pause_circle : Icons.play_circle),
            label: Text(
              active ? l10n.focusStopBreathing : l10n.focusStartBreathing,
            ),
          ),
        ],
      ),
    );
  }
}
