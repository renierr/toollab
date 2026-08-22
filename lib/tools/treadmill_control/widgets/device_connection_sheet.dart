import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';
import '../treadmill_control_state.dart';
import '../../../../l10n/app_localizations.dart';

class DeviceConnectionSheet extends StatelessWidget {
  const DeviceConnectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TreadmillControlState>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.toolNameBluetoothScanner,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    state.isScanning ? Icons.stop : Icons.refresh,
                    color: state.isScanning
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    if (state.isScanning) {
                      state.stopScan();
                    } else {
                      state.startScan();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.treadmillSimulateDevice,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: state.isSimulator,
                  onChanged: (val) {
                    state.toggleSimulator(val);
                    if (val) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            if (state.isScanning)
              const LinearProgressIndicator()
            else
              const Divider(),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Connected Devices Section
                    if (state.treadmillConnection ==
                            BleConnectionState.connected ||
                        state.hrmConnection ==
                            BleConnectionState.connected) ...[
                      Text(
                        l10n.treadmillConnectedDevices,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (state.treadmillConnection ==
                              BleConnectionState.connected &&
                          state.treadmillDeviceId != null)
                        ListTile(
                          leading: Icon(
                            Icons.directions_run_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            state.treadmillName ?? l10n.treadmillFallbackName,
                          ),
                          subtitle: Text(
                            l10n.treadmillConnectedStatus(
                              state.treadmillDeviceId!,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () => state.disconnectTreadmill(),
                            child: Text(
                              l10n.treadmillDisconnect,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      if (state.hrmConnection == BleConnectionState.connected &&
                          state.hrmDeviceId != null)
                        ListTile(
                          leading: const Icon(
                            Icons.favorite_border,
                            color: Colors.red,
                          ),
                          title: Text(
                            state.hrmName ?? l10n.treadmillHrmFallbackName,
                          ),
                          subtitle: Text(
                            l10n.treadmillConnectedStatus(state.hrmDeviceId!),
                          ),
                          trailing: TextButton(
                            onPressed: () => state.disconnectHrm(),
                            child: Text(
                              l10n.treadmillDisconnect,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      const Divider(),
                    ],
                    // Treadmills Section
                    Text(
                      l10n.treadmillScanTreadmills,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (state.discoveredTreadmills.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.treadmillScanNoTreadmills,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.discoveredTreadmills.length,
                        itemBuilder: (context, idx) {
                          final dev = state.discoveredTreadmills[idx];
                          final isCurrent = state.treadmillDeviceId == dev.id;
                          final isConnected =
                              state.treadmillConnection ==
                              BleConnectionState.connected;

                          return ListTile(
                            leading: Icon(
                              Icons.directions_run_outlined,
                              color: isConnected && isCurrent
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: Text(dev.name),
                            subtitle: Text('RSSI ${dev.rssi} | ${dev.id}'),
                            trailing: _buildConnectButton(
                              context: context,
                              isCurrent: isCurrent,
                              connectionState: state.treadmillConnection,
                              onConnect: () =>
                                  state.connectTreadmill(dev.id, dev.name),
                              onDisconnect: () => state.disconnectTreadmill(),
                            ),
                          );
                        },
                      ),
                    const Divider(),
                    // Heart Rate Monitors Section
                    Text(
                      l10n.treadmillScanHrms,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (state.discoveredHrms.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.treadmillScanNoHrms,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.discoveredHrms.length,
                        itemBuilder: (context, idx) {
                          final dev = state.discoveredHrms[idx];
                          final isCurrent = state.hrmDeviceId == dev.id;
                          final isConnected =
                              state.hrmConnection ==
                              BleConnectionState.connected;

                          return ListTile(
                            leading: Icon(
                              Icons.favorite_border,
                              color: isConnected && isCurrent
                                  ? Colors.red
                                  : null,
                            ),
                            title: Text(dev.name),
                            subtitle: Text('RSSI ${dev.rssi} | ${dev.id}'),
                            trailing: _buildConnectButton(
                              context: context,
                              isCurrent: isCurrent,
                              connectionState: state.hrmConnection,
                              onConnect: () =>
                                  state.connectHrm(dev.id, dev.name),
                              onDisconnect: () => state.disconnectHrm(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                state.stopScan();
                Navigator.of(context).pop();
              },
              child: Text(l10n.commonClose),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectButton({
    required BuildContext context,
    required bool isCurrent,
    required BleConnectionState connectionState,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (isCurrent) {
      if (connectionState == BleConnectionState.connecting) {
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      if (connectionState == BleConnectionState.connected) {
        return TextButton(
          onPressed: onDisconnect,
          child: Text(
            l10n.treadmillDisconnect,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        );
      }
    }
    return ElevatedButton(
      onPressed: onConnect,
      child: Text(l10n.treadmillConnect),
    );
  }
}
