import 'package:flutter/material.dart';
import 'package:tool_lab/tools/bluetooth_scanner/bluetooth_scanner_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

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
            _filterChip(
              context,
              DeviceFilter.highConfidence,
              l10n.bleFilterHighConfidence,
              Icons.verified_outlined,
            ),
            _filterChip(
              context,
              DeviceFilter.beacons,
              l10n.bleFilterBeacons,
              Icons.signal_cellular_alt,
            ),
            _filterChip(
              context,
              DeviceFilter.unknown,
              l10n.bleFilterUnknown,
              Icons.help_outline,
            ),
            _filterChip(
              context,
              DeviceFilter.recent,
              l10n.bleFilterRecent,
              Icons.schedule,
            ),
            _filterChip(
              context,
              DeviceFilter.strongSignal,
              l10n.bleFilterStrongSignal,
              Icons.signal_wifi_4_bar,
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(
    BuildContext context,
    DeviceFilter filter,
    String label,
    IconData icon,
  ) {
    final isActive = activeFilters.contains(filter);
    final theme = Theme.of(context);
    return FilterChip(
      selected: isActive,
      label: Text(label, style: theme.textTheme.labelSmall),
      avatar: Icon(icon, size: 14),
      onSelected: (_) => onToggleFilter(filter),
      visualDensity: VisualDensity.compact,
    );
  }
}
