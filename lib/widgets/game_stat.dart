import 'package:flutter/material.dart';

/// One labelled readout in a game's HUD — score, best, level, lives.
///
/// Scales its own text down rather than wrapping or clipping, so a five-digit
/// score in a narrow slot stays one readable line. Figures are tabular, which
/// stops a counter from jittering sideways as it ticks.
class GameStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  /// Centres the label and value, for a HUD column beside the board.
  final bool centered;

  const GameStat({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
