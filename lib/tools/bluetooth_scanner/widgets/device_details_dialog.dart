import 'package:flutter/material.dart';
import 'package:tool_lab/tools/bluetooth_scanner/data/scanned_device.dart';
import 'package:tool_lab/tools/bluetooth_scanner/bluetooth_scanner_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class DeviceDetailsDialog extends StatelessWidget {
  final ScannedDevice device;
  final DeviceHistoryEntry? history;

  const DeviceDetailsDialog({super.key, required this.device, this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              _infoRow(
                context,
                'Confidence',
                device.confidence.name.toUpperCase(),
              ),
              _infoRow(context, 'Category', device.identifiedCategory),
              _infoRow(context, 'Type', device.identifiedType),
              _infoRow(context, 'Role', device.likelyRole),
              _infoRow(context, 'RSSI', '${device.rssi} dBm'),
              if (device.estimatedDistance != null)
                _infoRow(
                  context,
                  'Distance',
                  '~${device.estimatedDistance!.toStringAsFixed(1)} m',
                ),
              if (device.manufacturer != null)
                _infoRow(context, 'Manufacturer', device.manufacturer!),
              if (device.knownName != null)
                _infoRow(context, 'Identified As', device.knownName!),
              if (history != null) ...[
                const Divider(height: 16),
                _infoRow(
                  context,
                  'First seen',
                  _formatDateTime(history!.firstSeen),
                ),
                _infoRow(
                  context,
                  'Last seen',
                  _formatDateTime(history!.lastSeen),
                ),
                _infoRow(context, 'Sightings', '${history!.sightings}'),
                if (history!.strongestRssi != null)
                  _infoRow(
                    context,
                    'Strongest RSSI',
                    '${history!.strongestRssi} dBm',
                  ),
              ],
              if (device.sensorData != null) ...[
                const Divider(height: 16),
                Text(
                  'Sensor Data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (device.sensorData!.temperatureCelsius != null)
                  _infoRow(
                    context,
                    'Temperature',
                    '${device.sensorData!.temperatureCelsius!.toStringAsFixed(1)} °C',
                  ),
                if (device.sensorData!.humidityPercent != null)
                  _infoRow(
                    context,
                    'Humidity',
                    '${device.sensorData!.humidityPercent!.toStringAsFixed(1)} %',
                  ),
                if (device.sensorData!.batteryPercent != null)
                  _infoRow(
                    context,
                    'Battery',
                    '${device.sensorData!.batteryPercent} %',
                  ),
              ],
              if (device.beacons.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  'Beacons',
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
                  'Services',
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
                  'Why identified',
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
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(reason, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
              ..._rawDataWidgets(theme),
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

  List<Widget> _rawDataWidgets(ThemeData theme) {
    final widgets = <Widget>[];
    if (device.manufacturerData == null && device.serviceDataRaw == null) {
      return widgets;
    }

    widgets.add(const Divider(height: 16));
    widgets.add(
      Text(
        'Raw Data',
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

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class ResponsiveAlertDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  const ResponsiveAlertDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: title,
            ),
            Flexible(
              child: Padding(padding: const EdgeInsets.all(16), child: content),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
