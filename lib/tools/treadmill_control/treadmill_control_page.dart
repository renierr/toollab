import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';
import 'treadmill_control_state.dart';
import 'treadmill_control_colors.dart';
import 'widgets/device_connection_sheet.dart';
import 'widgets/treadmill_active_session_dialog.dart';
import 'widgets/treadmill_recovered_session_dialog.dart';
import 'widgets/treadmill_settings_sheet.dart';
import 'widgets/workout_metrics_grid.dart';
import 'widgets/workout_controls_panel.dart';
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
  bool _recoveryPromptOpen = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<TreadmillControlState>();
    onDispose(() {
      // A recording session keeps its BLE links, timers and keep-alive leases
      // after the page is gone; only an idle tool may be torn down.
      if (!state.hasActiveSession) state.resetState(notify: false);
    });
    state.autoConnectSavedDevices();
  }

  Future<void> _handleRecovery(TreadmillControlState state) async {
    final session = state.recoveredSession;
    if (session == null || _recoveryPromptOpen) return;
    _recoveryPromptOpen = true;
    final choice = await TreadmillRecoveredSessionDialog.show(context, session);
    _recoveryPromptOpen = false;
    if (!mounted) return;
    switch (choice) {
      case TreadmillRecoveryChoice.resume:
        state.resumeRecoveredSession();
      case TreadmillRecoveryChoice.save:
        await state.saveRecoveredSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).treadmillRecoveredSaved,
              ),
            ),
          );
        }
      case TreadmillRecoveryChoice.discard:
        await state.discardRecoveredSession();
      case null:
        break;
    }
  }

  Future<void> _handleLeave() async {
    final navigator = Navigator.of(context);
    final state = context.read<TreadmillControlState>();
    final choice = await TreadmillActiveSessionDialog.show(context);
    if (!mounted || choice == null || choice == TreadmillLeaveChoice.stay) {
      return;
    }
    if (choice == TreadmillLeaveChoice.stopAndSave) {
      await state.stopWorkout();
    }
    if (mounted) navigator.pop();
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

    if (state.recoveredSession != null && !_recoveryPromptOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleRecovery(state);
      });
    }

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
        tooltip: l10n.treadmillConnectDevices,
        onPressed: _showConnectionSheet,
      ),
      IconButton(
        icon: const Icon(Icons.insights_outlined),
        tooltip: l10n.historyTitle,
        onPressed: () => context.push('/treadmill-control/history'),
      ),
      IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: l10n.healthDashboardSettings,
        onPressed: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => const TreadmillSettingsSheet(),
        ),
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

    return PopScope(
      canPop: !state.hasActiveSession,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleLeave();
      },
      child: ToolLayout(
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
                    ],
                  ),
                ),
              ),
            ],
          ),
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
