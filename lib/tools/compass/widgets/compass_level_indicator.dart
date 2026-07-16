import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import '../compass_state.dart';

/// Shows how flat the device is held. Turns green when level enough for an
/// accurate heading, amber with a hint otherwise. Hidden in simulation mode.
class CompassLevelIndicator extends StatelessWidget {
  const CompassLevelIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CompassState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (state.useSimulation) return const SizedBox.shrink();

    final bool level = state.isLevel;
    final Color color = level ? AppTheme.statusGreen : AppTheme.statusAmber;
    final String tilt = state.tiltDegrees.toStringAsFixed(0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                level
                    ? Icons.check_circle_outline
                    : Icons.screen_rotation_alt_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                level ? l10n.compassLevelGood : l10n.compassLevelHoldFlat,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.compassTiltLabel(tilt),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (!level) ...[
          const SizedBox(height: 6),
          Text(
            l10n.compassHoldFlatHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
