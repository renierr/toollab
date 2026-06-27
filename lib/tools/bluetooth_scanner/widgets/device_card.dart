import 'package:flutter/material.dart';
import 'package:tool_lab/tools/bluetooth_scanner/data/scanned_device.dart';
import 'package:tool_lab/tools/bluetooth_scanner/bluetooth_scanner_state.dart';

class DeviceCard extends StatelessWidget {
  final ScannedDevice device;
  final DeviceHistoryEntry? history;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signalBars = _getSignalBars(device.rssi);
    final confidenceColor = _confidenceColor(theme, device.confidence);
    final name = device.knownName ?? device.name;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _categoryIcon(
                      device.identifiedCategory,
                      device.beacons.isNotEmpty,
                    ),
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (device.paired == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        Icons.link,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  _TransportBadge(transport: device.transport),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      device.confidence.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: confidenceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (device.transport == Transport.ble) ...[
                    _signalIcon(signalBars, theme),
                    const SizedBox(width: 4),
                    Text(
                      '${device.rssi} dBm',
                      style: theme.textTheme.labelSmall,
                    ),
                  ] else
                    Icon(
                      Icons.bluetooth,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  if (device.manufacturer != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        device.manufacturer!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (device.transport == Transport.ble &&
                  device.serviceNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 2,
                    children: device.serviceNames
                        .take(2)
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              s,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _getSignalBars(int rssi) {
    if (rssi >= -50) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -80) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }

  Widget _signalIcon(int bars, ThemeData theme) {
    return Row(
      children: List.generate(4, (i) {
        return Container(
          width: 4,
          height: 4 + i * 3,
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: i < bars
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Color _confidenceColor(ThemeData theme, Confidence c) {
    switch (c) {
      case Confidence.high:
        return Colors.green;
      case Confidence.medium:
        return Colors.orange;
      case Confidence.low:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(String category, bool isBeacon) {
    if (isBeacon) return Icons.signal_cellular_alt;
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
      case 'Beacon':
        return Icons.signal_cellular_alt;
      default:
        return Icons.devices_other;
    }
  }
}

class _TransportBadge extends StatelessWidget {
  final Transport transport;

  const _TransportBadge({required this.transport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBle = transport == Transport.ble;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: (isBle ? Colors.blue : Colors.indigo).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isBle ? 'BLE' : 'CL',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 7,
          fontWeight: FontWeight.bold,
          color: isBle ? Colors.blue : Colors.indigo,
        ),
      ),
    );
  }
}
