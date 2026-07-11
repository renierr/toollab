import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/status_badge.dart';
import '../compass_state.dart';

class InterferencePanel extends StatelessWidget {
  const InterferencePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CompassState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final double strength = state.magneticFieldStrength;
    final bool hasInterference =
        state.interferenceStatus == CompassInterferenceStatus.warning;

    final badgeColor = hasInterference
        ? AppTheme.statusRed
        : AppTheme.statusGreen;
    final badgeLabel = hasInterference
        ? l10n.compassInterferenceWarning
        : l10n.compassInterferenceNormal;
    final badgeIcon = hasInterference
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline;

    return InfoCard(
      icon: Icons.network_check_outlined,
      title: l10n.compassMagneticField,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${strength.toStringAsFixed(1)} μT',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              StatusBadge(
                label: badgeLabel,
                color: badgeColor,
                icon: badgeIcon,
                showDot: !hasInterference,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.compassCalibrateTip,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
