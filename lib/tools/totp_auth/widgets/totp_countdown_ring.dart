import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

class TotpCountdownRing extends StatelessWidget {
  final int remaining;
  final int period;
  final double size;

  const TotpCountdownRing({
    super.key,
    required this.remaining,
    required this.period,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = period <= 0 ? 0.0 : remaining / period;
    final urgent = remaining <= 5;
    final color = urgent ? AppTheme.accentRed : theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.4,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size * 0.22),
            child: FittedBox(
              child: Text(
                '$remaining',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: urgent ? AppTheme.accentRed : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
