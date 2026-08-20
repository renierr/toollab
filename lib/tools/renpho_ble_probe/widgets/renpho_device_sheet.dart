import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../renpho_ble_probe_state.dart';

/// Picking the scale by hand, for a unit that advertises under a name the
/// automatic match does not know.
class RenphoDeviceSheet extends StatelessWidget {
  const RenphoDeviceSheet({super.key});

  static Future<void> show(BuildContext context) {
    final state = context.read<RenphoBleProbeState>();
    if (!state.scanning) state.startScan();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RenphoDeviceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RenphoBleProbeState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.renphoDevicesTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: state.scanning
                        ? l10n.renphoStopScan
                        : l10n.renphoStartScan,
                    icon: Icon(state.scanning ? Icons.stop : Icons.refresh),
                    onPressed: () =>
                        state.scanning ? state.stopScan() : state.startScan(),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.renphoAutoConnect),
                subtitle: Text(l10n.renphoAutoConnectSubtitle),
                value: state.autoConnect,
                onChanged: state.setAutoConnect,
              ),
              if (state.scanning) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: state.discovered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.renphoNoDevices,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.discovered.length,
                        itemBuilder: (context, index) {
                          final device = state.discovered[index];
                          final remembered =
                              device.id == state.rememberedDeviceId;
                          return ListTile(
                            leading: Icon(
                              Icons.monitor_weight_outlined,
                              color: remembered
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: Text(device.name),
                            subtitle: Text('${device.rssi} dBm  ${device.id}'),
                            trailing: state.deviceId == device.id
                                ? Text(l10n.renphoConnected)
                                : FilledButton.tonal(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      state.connect(device.id, device.name);
                                    },
                                    child: Text(l10n.renphoConnect),
                                  ),
                          );
                        },
                      ),
              ),
              if (state.rememberedDeviceId != null)
                TextButton.icon(
                  onPressed: () {
                    state.forgetDevice();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.link_off),
                  label: Text(l10n.renphoForgetDevice),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
