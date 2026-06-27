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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _categoryIcon(
                      device.identifiedCategory,
                      device.beacons.isNotEmpty,
                    ),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      device.confidence.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: confidenceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _signalIcon(signalBars, theme),
                  const SizedBox(width: 6),
                  Text('${device.rssi} dBm', style: theme.textTheme.bodySmall),
                  if (device.manufacturer != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.business,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        device.manufacturer!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (device.serviceNames.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: device.serviceNames
                      .take(3)
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (device.hints.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  device.hints.take(2).join(' • '),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (history != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${history!.sightings} sighting${history!.sightings == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
              ],
              Text(
                device.likelyRole,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 9,
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
