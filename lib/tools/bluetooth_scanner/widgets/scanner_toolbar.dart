import 'package:flutter/material.dart';
import 'package:tool_lab/tools/bluetooth_scanner/bluetooth_scanner_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'scanner_filter_chip.dart';

class ScannerToolbar extends StatelessWidget {
  final bool isScanning;
  final bool isBluetoothOn;
  final bool permissionGranted;
  final Set<DeviceFilter> activeFilters;
  final VoidCallback onScan;
  final VoidCallback onStop;
  final VoidCallback onClear;
  final VoidCallback onClearHistory;
  final void Function(DeviceFilter) onToggleFilter;
  final String? error;

  const ScannerToolbar({
    super.key,
    required this.isScanning,
    required this.isBluetoothOn,
    required this.permissionGranted,
    required this.activeFilters,
    required this.onScan,
    required this.onStop,
    required this.onClear,
    required this.onClearHistory,
    required this.onToggleFilter,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isScanning ? onStop : onScan,
                icon: Icon(isScanning ? Icons.stop : Icons.bluetooth_searching),
                label: Text(isScanning ? l10n.bleStopScan : l10n.bleStartScan),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: isScanning ? null : onClear,
              child: Text(l10n.commonClear),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onClearHistory,
              tooltip: l10n.bleClearHistory,
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ScannerFilterChip(
              filter: DeviceFilter.highConfidence,
              label: l10n.bleFilterHighConfidence,
              icon: Icons.verified_outlined,
              isActive: activeFilters.contains(DeviceFilter.highConfidence),
              onToggle: onToggleFilter,
            ),
            ScannerFilterChip(
              filter: DeviceFilter.beacons,
              label: l10n.bleFilterBeacons,
              icon: Icons.signal_cellular_alt,
              isActive: activeFilters.contains(DeviceFilter.beacons),
              onToggle: onToggleFilter,
            ),
            ScannerFilterChip(
              filter: DeviceFilter.unknown,
              label: l10n.bleFilterUnknown,
              icon: Icons.help_outline,
              isActive: activeFilters.contains(DeviceFilter.unknown),
              onToggle: onToggleFilter,
            ),
            ScannerFilterChip(
              filter: DeviceFilter.recent,
              label: l10n.bleFilterRecent,
              icon: Icons.schedule,
              isActive: activeFilters.contains(DeviceFilter.recent),
              onToggle: onToggleFilter,
            ),
            ScannerFilterChip(
              filter: DeviceFilter.strongSignal,
              label: l10n.bleFilterStrongSignal,
              icon: Icons.signal_wifi_4_bar,
              isActive: activeFilters.contains(DeviceFilter.strongSignal),
              onToggle: onToggleFilter,
            ),
          ],
        ),
      ],
    );
  }
}
