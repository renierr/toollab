import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';
import '../treadmill_control_state.dart';
import 'package:tool_lab/widgets/workout/workout_colors.dart';
import '../../../../l10n/app_localizations.dart';

class ConnectionStatusIndicators extends StatelessWidget {
  const ConnectionStatusIndicators({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IndicatorDot(
          icon: Icons.directions_run_outlined,
          connectionState: state.treadmillConnection,
          tooltip:
              '${l10n.treadmillBadgeTreadmill}: '
              '${_statusLabel(l10n, state.treadmillConnection)}',
        ),
        const SizedBox(width: 8),
        _IndicatorDot(
          icon: Icons.favorite,
          connectionState: state.hrmConnection,
          tooltip:
              '${l10n.hrLabel}: ${_statusLabel(l10n, state.hrmConnection)}',
        ),
      ],
    );
  }

  String _statusLabel(AppLocalizations l10n, BleConnectionState s) {
    switch (s) {
      case BleConnectionState.connected:
        return l10n.treadmillStatusConnected;
      case BleConnectionState.connecting:
        return l10n.treadmillStatusConnecting;
      default:
        return l10n.treadmillStatusDisconnected;
    }
  }
}

class _IndicatorDot extends StatelessWidget {
  final IconData icon;
  final BleConnectionState connectionState;
  final String tooltip;

  const _IndicatorDot({
    required this.icon,
    required this.connectionState,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color = switch (connectionState) {
      BleConnectionState.connected => TreadmillColors.greenMetric,
      BleConnectionState.connecting => TreadmillColors.amberMetric,
      _ => theme.colorScheme.outline,
    };

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 20, color: color),
    );
  }
}
