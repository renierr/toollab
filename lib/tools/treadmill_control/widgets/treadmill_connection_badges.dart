import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/status_badge.dart';
import 'package:universal_ble/universal_ble.dart';

class TreadmillConnectionBadges extends StatelessWidget {
  final BleConnectionState treadmillState;
  final String? treadmillType;
  final BleConnectionState hrmState;
  final VoidCallback onTap;

  const TreadmillConnectionBadges({
    super.key,
    required this.treadmillState,
    this.treadmillType,
    required this.hrmState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TreadmillDeviceBadge(
          label: l10n.treadmillLabel,
          connectionState: treadmillState,
          deviceType: treadmillType,
          onTap: onTap,
        ),
        TreadmillDeviceBadge(
          label: l10n.hrLabel,
          connectionState: hrmState,
          onTap: onTap,
        ),
      ],
    );
  }
}

class TreadmillDeviceBadge extends StatelessWidget {
  final String label;
  final BleConnectionState connectionState;
  final String? deviceType;
  final VoidCallback onTap;

  const TreadmillDeviceBadge({
    super.key,
    required this.label,
    required this.connectionState,
    this.deviceType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isConnected = connectionState == BleConnectionState.connected;
    final isConnecting = connectionState == BleConnectionState.connecting;

    String statusText = l10n.treadmillStatusDisconnected;
    Color badgeColor = AppTheme.statusRed;

    if (isConnected) {
      statusText = deviceType != null
          ? '${l10n.treadmillStatusConnected} ($deviceType)'
          : l10n.treadmillStatusConnected;
      badgeColor = AppTheme.statusGreen;
    } else if (isConnecting) {
      statusText = l10n.treadmillStatusConnecting;
      badgeColor = AppTheme.statusAmber;
    }

    return StatusBadge(
      label: '$label: $statusText',
      color: badgeColor,
      showDot: true,
      onTap: onTap,
    );
  }
}
