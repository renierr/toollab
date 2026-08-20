import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/status_badge.dart';

import '../renpho_ble_probe_state.dart';
import '../renpho_colors.dart';
import '../renpho_error_message.dart';
import 'renpho_measure_steps.dart';

/// The live readout: what the scale is measuring right now, what the tool is
/// waiting for, and the one button that starts or stops it.
class RenphoScanCard extends StatelessWidget {
  final VoidCallback onScan;

  const RenphoScanCard({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final weight = state.liveWeightKg ?? state.latest?.weightKg;
    final live = state.liveWeightKg != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _PhaseBadge(phase: state.phase)),
                if (state.deviceName != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: StatusBadge(
                      label: state.deviceName!,
                      color: theme.colorScheme.outline,
                      icon: Icons.bluetooth,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    weight == null ? '--.--' : weight.toStringAsFixed(2),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: live ? RenphoColors.weight : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('kg', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Once the scale is set up the step indicator carries the
            // instructions, so the flat status line would only repeat it.
            if (_showSteps(state.phase))
              RenphoMeasureSteps(step: state.measureStep)
            else
              Text(
                _status(l10n, state),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (state.importedStoredRecords > 0) ...[
              const SizedBox(height: 6),
              Text(
                l10n.renphoImportedStored(state.importedStoredRecords),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.statusGreen,
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 10),
              Text(
                renphoErrorMessage(l10n, state.error!, state.errorDetail),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onScan,
                icon: Icon(
                  state.busy || state.connected
                      ? Icons.stop_rounded
                      : Icons.bluetooth_searching,
                ),
                label: Text(
                  state.busy || state.connected
                      ? l10n.renphoStopScan
                      : l10n.renphoStartScan,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _showSteps(RenphoScanPhase phase) =>
      phase == RenphoScanPhase.ready ||
      phase == RenphoScanPhase.saving ||
      phase == RenphoScanPhase.complete;

  String _status(AppLocalizations l10n, RenphoBleProbeState state) {
    if (state.retryingSetup) return l10n.renphoStatusRetrying;
    return switch (state.phase) {
      RenphoScanPhase.idle => l10n.renphoStatusIdle,
      RenphoScanPhase.discovering => l10n.renphoStatusDiscovering,
      RenphoScanPhase.connecting => l10n.renphoStatusConnecting,
      RenphoScanPhase.preparing => l10n.renphoStatusPreparing,
      RenphoScanPhase.ready => l10n.renphoStatusReady,
      RenphoScanPhase.saving => l10n.renphoStatusSaving,
      RenphoScanPhase.complete => l10n.renphoStatusComplete,
    };
  }
}

class _PhaseBadge extends StatelessWidget {
  final RenphoScanPhase phase;

  const _PhaseBadge({required this.phase});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (phase) {
      RenphoScanPhase.idle => (
        l10n.renphoPhaseIdle,
        Theme.of(context).hintColor,
      ),
      RenphoScanPhase.discovering => (
        l10n.renphoPhaseDiscovering,
        AppTheme.accentBlue,
      ),
      RenphoScanPhase.connecting => (
        l10n.renphoPhaseConnecting,
        AppTheme.accentBlue,
      ),
      RenphoScanPhase.preparing => (
        l10n.renphoPhasePreparing,
        AppTheme.statusAmber,
      ),
      RenphoScanPhase.ready => (l10n.renphoPhaseReady, AppTheme.statusGreen),
      RenphoScanPhase.saving => (l10n.renphoPhaseSaving, AppTheme.accentTeal),
      RenphoScanPhase.complete => (
        l10n.renphoPhaseComplete,
        AppTheme.statusGreen,
      ),
    };
    return StatusBadge(label: label, color: color, showDot: true);
  }
}
