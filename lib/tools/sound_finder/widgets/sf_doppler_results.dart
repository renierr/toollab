import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'sf_readout.dart';

class SfDopplerResults extends StatelessWidget {
  final double fApproach;
  final double fRecede;
  final double distance;
  final double temperature;

  const SfDopplerResults({
    super.key,
    required this.fApproach,
    required this.fRecede,
    required this.distance,
    required this.temperature,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Speed of sound c (m/s)
    final double c = 331.3 + 0.606 * temperature;

    // Doppler calculation
    final double denom = fApproach + fRecede;
    final double f0 = denom > 0 ? (2.0 * fApproach * fRecede) / denom : 0.0;
    final double v = denom > 0 ? c * (fApproach - fRecede) / denom : 0.0;

    // Speed in km/h and mph
    final double vKmh = v * 3.6;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sfDopplerParameters,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                SfReadout(
                  label: l10n.sfDopplerVelocity,
                  value:
                      '${v.toStringAsFixed(1)} m/s (${vKmh.toStringAsFixed(1)} km/h)',
                  valueColor: theme.colorScheme.primary,
                ),
                SfReadout(
                  label: l10n.sfDopplerSourceFreq,
                  value: '${f0.toStringAsFixed(1)} Hz',
                ),
                SfReadout(
                  label: l10n.sfDopplerDistance,
                  value: '${distance.toStringAsFixed(1)} m',
                ),
                SfReadout(
                  label: l10n.sfDopplerSpeedOfSound,
                  value: '${c.toStringAsFixed(1)} m/s',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
