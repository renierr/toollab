import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';
import 'treadmill_control_state.dart';
import 'treadmill_control_colors.dart';
import 'widgets/device_connection_sheet.dart';
import 'widgets/workout_metrics_grid.dart';
import 'widgets/workout_controls_panel.dart';
import 'widgets/session_history_list.dart';
import '../../core/tool_page_state.dart';
import '../../widgets/tool_layout.dart';
import '../../widgets/responsive_orientation_layout.dart';
import '../../widgets/status_badge.dart';
import '../../../l10n/app_localizations.dart';

class TreadmillControlPage extends StatefulWidget {
  const TreadmillControlPage({super.key});

  @override
  State<TreadmillControlPage> createState() => _TreadmillControlPageState();
}

class _TreadmillControlPageState extends State<TreadmillControlPage>
    with DisposeCleanup {
  @override
  void initState() {
    super.initState();
    final state = context.read<TreadmillControlState>();
    onDispose(() {
      state.resetState(notify: false);
    });
  }

  void _showConnectionSheet() {
    final state = context.read<TreadmillControlState>();
    state.startScan();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DeviceConnectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    state.notificationTitle = l10n.treadmillNotificationTitle;
    state.notificationText = l10n.treadmillNotificationText;

    final List<Widget> actions = [
      IconButton(
        icon: Icon(
          state.wakeLockEnabled
              ? Icons.screen_lock_rotation
              : Icons.screen_lock_rotation_outlined,
          color: state.wakeLockEnabled ? TreadmillColors.amberMetric : null,
        ),
        tooltip: l10n.levelWakeLock,
        onPressed: () => state.toggleWakeLock(),
      ),
      IconButton(
        icon: const Icon(Icons.bluetooth),
        tooltip: 'Connect Devices',
        onPressed: _showConnectionSheet,
      ),
    ];

    final Widget connectionBadges = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildDeviceBadge(
          context: context,
          label: 'Treadmill',
          connectionState: state.treadmillConnection,
          deviceType: state.treadmillType == TreadmillType.pitpat
              ? 'PITPAT'
              : (state.treadmillType == TreadmillType.ftms ? 'FTMS' : null),
          onTap: _showConnectionSheet,
        ),
        _buildDeviceBadge(
          context: context,
          label: 'Heart Rate',
          connectionState: state.hrmConnection,
          onTap: _showConnectionSheet,
        ),
      ],
    );

    return ToolLayout(
      title: 'Treadmill Control',
      actions: actions,
      child: ResponsiveOrientationLayout(
        portrait: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkoutMetricsGrid(isLandscape: false),
              const SizedBox(height: 16),
              WorkoutControlsPanel(isLandscape: false),
              const SizedBox(height: 24),
              connectionBadges,
              const SizedBox(height: 16),
              const SessionHistoryList(),
            ],
          ),
        ),
        landscape: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [WorkoutControlsPanel(isLandscape: true)],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: theme.dividerColor),
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WorkoutMetricsGrid(isLandscape: true),
                    const SizedBox(height: 24),
                    connectionBadges,
                    const SizedBox(height: 16),
                    const SessionHistoryList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceBadge({
    required BuildContext context,
    required String label,
    required BleConnectionState connectionState,
    String? deviceType,
    required VoidCallback onTap,
  }) {
    final isConnected = connectionState == BleConnectionState.connected;
    final isConnecting = connectionState == BleConnectionState.connecting;

    String statusText = 'Disconnected';
    Color badgeColor = Colors.red;

    if (isConnected) {
      statusText = deviceType != null ? 'Connected ($deviceType)' : 'Connected';
      badgeColor = Colors.green;
    } else if (isConnecting) {
      statusText = 'Connecting...';
      badgeColor = Colors.amber;
    }

    return StatusBadge(
      label: '$label: $statusText',
      color: badgeColor,
      showDot: true,
      onTap: onTap,
    );
  }
}
