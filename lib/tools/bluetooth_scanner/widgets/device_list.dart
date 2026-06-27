import 'package:flutter/material.dart';
import 'package:tool_lab/tools/bluetooth_scanner/data/scanned_device.dart';
import 'package:tool_lab/tools/bluetooth_scanner/bluetooth_scanner_state.dart';
import 'device_card.dart';
import 'device_details_dialog.dart';

class DeviceList extends StatelessWidget {
  final Map<String, ScannedDevice> devices;
  final Map<String, DeviceHistoryEntry> history;
  final Set<DeviceFilter> activeFilters;
  final Set<String> collapsedCategories;
  final void Function(String category) onToggleCategory;
  final void Function(ScannedDevice device) onDeviceTap;

  const DeviceList({
    super.key,
    required this.devices,
    required this.history,
    required this.activeFilters,
    required this.collapsedCategories,
    required this.onToggleCategory,
    required this.onDeviceTap,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = _filterDevices(context);
    if (filtered.isEmpty) {
      return _emptyState(context);
    }

    final grouped = _groupByCategory(filtered);
    final sortedCategories = grouped.keys.toList()..sort(_compareCategory);

    return ListView.builder(
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final categoryDevices = grouped[category]!;
        final isCollapsed = collapsedCategories.contains(category);
        final icon = _categoryIcon(category);
        final count = categoryDevices.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              InkWell(
                onTap: () => onToggleCategory(category),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isCollapsed ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.4,
                        ),
                    itemCount: categoryDevices.length,
                    itemBuilder: (context, i) {
                      final device = categoryDevices[i];
                      final hist = history[device.fingerprint];
                      return DeviceCard(
                        device: device,
                        history: hist,
                        onTap: () => _showDetails(context, device, hist),
                      );
                    },
                  ),
                ),
                crossFadeState: isCollapsed
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ScannedDevice> _filterDevices(BuildContext context) {
    if (activeFilters.isEmpty) return devices.values.toList();

    final now = DateTime.now();
    return devices.values.where((d) {
      final hist = history[d.fingerprint];
      for (final filter in activeFilters) {
        switch (filter) {
          case DeviceFilter.highConfidence:
            if (d.confidence != Confidence.high) return false;
          case DeviceFilter.beacons:
            if (d.beacons.isEmpty) return false;
          case DeviceFilter.unknown:
            if (d.identifiedCategory != 'Unknown') return false;
          case DeviceFilter.recent:
            final lastSeen = hist?.lastSeen ?? d.timestamp;
            if (now.difference(lastSeen).inMinutes > 5) return false;
          case DeviceFilter.strongSignal:
            if (d.rssi < -65) return false;
        }
      }
      return true;
    }).toList();
  }

  Map<String, List<ScannedDevice>> _groupByCategory(
    List<ScannedDevice> filtered,
  ) {
    final grouped = <String, List<ScannedDevice>>{};
    final unknown = <ScannedDevice>[];
    final unknownByMfr = <String, List<ScannedDevice>>{};

    for (final d in filtered) {
      if (d.beacons.isNotEmpty) {
        grouped.putIfAbsent('Beacons', () => []).add(d);
      } else if (d.identifiedCategory == 'Unknown') {
        unknown.add(d);
      } else {
        grouped.putIfAbsent(d.identifiedCategory, () => []).add(d);
      }
    }

    for (final d in unknown) {
      if (d.manufacturer != null) {
        unknownByMfr.putIfAbsent(d.manufacturer!, () => []).add(d);
      } else {
        grouped.putIfAbsent('Unidentified', () => []).add(d);
      }
    }

    for (final entry in unknownByMfr.entries) {
      grouped
          .putIfAbsent('Unknown - ${entry.key}', () => [])
          .addAll(entry.value);
    }

    return grouped;
  }

  int _compareCategory(String a, String b) {
    const order = [
      'Beacons',
      'Audio',
      'Wearables',
      'Health',
      'Fitness',
      'IoT',
      'Phones',
      'Computers',
      'Input',
      'Gaming',
      'Vehicle',
      'Unidentified',
    ];
    final ai = order.indexOf(a);
    final bi = order.indexOf(b);
    if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
    if (ai >= 0) return -1;
    if (bi >= 0) return 1;
    return a.compareTo(b);
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No devices found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning to discover nearby BLE devices',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    if (category.startsWith('Beacon')) return Icons.signal_cellular_alt;
    if (category.startsWith('Unknown')) return Icons.help_outline;
    if (category.startsWith('Unidentified')) return Icons.devices_other;
    switch (category) {
      case 'Audio':
        return Icons.headphones;
      case 'Wearables':
        return Icons.watch;
      case 'Health':
        return Icons.favorite;
      case 'Fitness':
        return Icons.directions_run;
      case 'IoT':
        return Icons.lightbulb_outline;
      case 'Phones':
        return Icons.phone_android;
      case 'Computers':
        return Icons.computer;
      case 'Input':
        return Icons.keyboard;
      case 'Gaming':
        return Icons.sports_esports;
      case 'Vehicle':
        return Icons.directions_car;
      default:
        return Icons.devices_other;
    }
  }

  void _showDetails(
    BuildContext context,
    ScannedDevice device,
    DeviceHistoryEntry? history,
  ) {
    showDialog(
      context: context,
      builder: (_) => DeviceDetailsDialog(device: device, history: history),
    );
  }
}
