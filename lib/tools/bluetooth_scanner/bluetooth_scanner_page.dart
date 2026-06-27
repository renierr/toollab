import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';
import 'bluetooth_scanner_state.dart';
import 'widgets/scanner_toolbar.dart';
import 'widgets/device_list.dart';
import 'widgets/scan_status_badge.dart';

class BluetoothScannerPage extends StatefulWidget {
  const BluetoothScannerPage({super.key});

  @override
  State<BluetoothScannerPage> createState() => _BluetoothScannerPageState();
}

class _BluetoothScannerPageState extends State<BluetoothScannerPage>
    with DisposeCleanup<BluetoothScannerPage> {
  @override
  void initState() {
    super.initState();
    onDispose(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BluetoothScannerState>();
    final l10n = AppLocalizations.of(context);

    return ToolLayout(
      title: BluetoothScannerTool.config.localizedName(l10n),
      fullscreen: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ScannerToolbar(
              isScanning: state.isScanning,
              isBluetoothOn: state.isBluetoothOn,
              permissionGranted: state.permissionGranted,
              activeFilters: state.activeFilters,
              onScan: () => state.startScan(),
              onStop: () => state.stopScan(),
              onClear: () => state.clearDevices(),
              onClearHistory: () => state.clearHistory(),
              onToggleFilter: (f) => state.toggleFilter(f),
              error: state.error,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ScanStatusBadge(
                  isScanning: state.isScanning,
                  deviceCount: state.deviceCount,
                ),
                if (!state.isBluetoothOn)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Bluetooth Off',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DeviceList(
              devices: state.devices,
              history: state.history,
              activeFilters: state.activeFilters,
              collapsedCategories: state.collapsedCategories,
              onToggleCategory: (c) => state.toggleCategory(c),
              onDeviceTap: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
