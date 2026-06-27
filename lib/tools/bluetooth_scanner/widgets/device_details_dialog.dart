import 'package:flutter/material.dart';
import 'package:tool_lab/tools/bluetooth_scanner/data/scanned_device.dart';
import 'package:tool_lab/tools/bluetooth_scanner/bluetooth_scanner_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';
import 'device_info_row.dart';

class DeviceDetailsDialog extends StatelessWidget {
  final ScannedDevice device;
  final DeviceHistoryEntry? history;

  const DeviceDetailsDialog({super.key, required this.device, this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ResponsiveAlertDialog(
      title: SelectionArea(
        child: Row(
          children: [
            Icon(Icons.bluetooth, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                device.knownName ?? device.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DeviceInfoRow(
                label: l10n.bleDetailConfidence,
                value: switch (device.confidence) {
                  Confidence.high => l10n.bleFilterHighConfidence,
                  Confidence.medium => l10n.bleConfidenceMedium,
                  Confidence.low => l10n.bleConfidenceLow,
                }.toUpperCase(),
              ),
              DeviceInfoRow(
                label: l10n.bleDetailCategory,
                value: device.identifiedCategory,
              ),
              DeviceInfoRow(
                label: l10n.bleDetailType,
                value: device.identifiedType,
              ),
              DeviceInfoRow(
                label: l10n.bleDetailRole,
                value: device.likelyRole,
              ),
              DeviceInfoRow(
                label: l10n.bleDetailRSSI,
                value: '${device.rssi} dBm',
              ),
              if (device.estimatedDistance != null)
                DeviceInfoRow(
                  label: l10n.bleDetailDistance,
                  value: '~${device.estimatedDistance!.toStringAsFixed(1)} m',
                ),
              if (device.manufacturer != null)
                DeviceInfoRow(
                  label: l10n.bleDetailManufacturer,
                  value: device.manufacturer!,
                ),
              if (device.knownName != null)
                DeviceInfoRow(
                  label: l10n.bleDetailIdentifiedAs,
                  value: device.knownName!,
                ),
              if (history != null) ...[
                const Divider(height: 16),
                DeviceInfoRow(
                  label: l10n.bleDetailFirstSeen,
                  value: _formatDateTime(context, history!.firstSeen),
                ),
                DeviceInfoRow(
                  label: l10n.bleDetailLastSeen,
                  value: _formatDateTime(context, history!.lastSeen),
                ),
                DeviceInfoRow(
                  label: l10n.bleDetailSightings,
                  value: '${history!.sightings}',
                ),
                if (history!.strongestRssi != null)
                  DeviceInfoRow(
                    label: l10n.bleDetailStrongestRSSI,
                    value: '${history!.strongestRssi} dBm',
                  ),
              ],
              if (device.sensorData != null) ...[
                const Divider(height: 16),
                Text(
                  l10n.bleDetailSensorData,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (device.sensorData!.temperatureCelsius != null)
                  DeviceInfoRow(
                    label: l10n.bleDetailTemperature,
                    value:
                        '${device.sensorData!.temperatureCelsius!.toStringAsFixed(1)} °C',
                  ),
                if (device.sensorData!.humidityPercent != null)
                  DeviceInfoRow(
                    label: l10n.bleDetailHumidity,
                    value:
                        '${device.sensorData!.humidityPercent!.toStringAsFixed(1)} %',
                  ),
                if (device.sensorData!.batteryPercent != null)
                  DeviceInfoRow(
                    label: l10n.bleDetailBattery,
                    value: '${device.sensorData!.batteryPercent} %',
                  ),
              ],
              if (device.beacons.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  l10n.bleDetailBeacons,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                for (final beacon in device.beacons) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beacon.type,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(beacon.format, style: theme.textTheme.bodySmall),
                        if (beacon.details.isNotEmpty)
                          ...beacon.details.map(
                            (d) => Text(d, style: theme.textTheme.bodySmall),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
              if (device.serviceNames.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  l10n.bleDetailServices,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: device.serviceNames
                      .map(
                        (s) => Chip(
                          label: Text(s, style: theme.textTheme.labelSmall),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (device.confidenceReasons.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  l10n.bleDetailWhyIdentified,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                for (final reason in device.confidenceReasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: AppTheme.statusGreen,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(reason, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
              ..._rawDataWidgets(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonClose),
        ),
      ],
    );
  }

  List<Widget> _rawDataWidgets(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final widgets = <Widget>[];
    if (device.manufacturerData == null && device.serviceDataRaw == null) {
      return widgets;
    }

    widgets.add(const Divider(height: 16));
    widgets.add(
      Text(
        l10n.bleDetailRawData,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 4));

    if (device.manufacturerData != null) {
      for (final entry in device.manufacturerData!.entries) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mfr 0x${entry.key.toRadixString(16).padLeft(4, '0').toUpperCase()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (device.serviceDataRaw != null) {
      for (final entry in device.serviceDataRaw!.entries) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service ${entry.key}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  String _formatDateTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final l10n = AppLocalizations.of(context);
    if (diff.inSeconds < 60) return l10n.bleTimeJustNow;
    if (diff.inMinutes < 60) return l10n.bleTimeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.bleTimeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.bleTimeDaysAgo(diff.inDays);
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
