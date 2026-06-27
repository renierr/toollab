import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';
import 'treadmill_control_state.dart';
import 'treadmill_control_colors.dart';
import 'widgets/device_connection_sheet.dart';
import 'widgets/workout_metrics_grid.dart';
import 'widgets/workout_controls_panel.dart';
import 'widgets/workout_chart.dart';
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
    onDispose(() {
      final state = context.read<TreadmillControlState>();
      state.stopScan();
      state.disconnectTreadmill();
      state.disconnectHrm();
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
    final isDark = theme.brightness == Brightness.dark;

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

    final Widget connectionBar = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Connections',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const Text('Simulator'),
                  const SizedBox(width: 4),
                  Switch(
                    value: state.isSimulator,
                    onChanged: (val) => state.toggleSimulator(val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDeviceBadge(
                context: context,
                label: 'Treadmill',
                connectionState: state.treadmillConnection,
                deviceType: state.treadmillType == TreadmillType.pitpat
                    ? 'PITPAT'
                    : (state.treadmillType == TreadmillType.ftms
                          ? 'FTMS'
                          : null),
                onTap: _showConnectionSheet,
              ),
              _buildDeviceBadge(
                context: context,
                label: 'Heart Rate',
                connectionState: state.hrmConnection,
                onTap: _showConnectionSheet,
              ),
            ],
          ),
        ],
      ),
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
              connectionBar,
              const SizedBox(height: 16),
              WorkoutMetricsGrid(isLandscape: false),
              const SizedBox(height: 16),
              const WorkoutChart(),
              const SizedBox(height: 16),
              WorkoutControlsPanel(isLandscape: false),
              const SizedBox(height: 24),
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
                  children: [
                    connectionBar,
                    const SizedBox(height: 16),
                    WorkoutControlsPanel(isLandscape: true),
                    const SizedBox(height: 16),
                    const WorkoutChart(),
                  ],
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
