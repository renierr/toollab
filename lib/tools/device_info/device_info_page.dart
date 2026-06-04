import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Battery _battery = Battery();
  Map<String, String> _info = {};
  int? _batteryLevel;
  BatteryState? _batteryState;
  bool _loading = true;
  StreamSubscription<BatteryState>? _batterySubscription;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
        if (mounted) setState(() => _batteryState = state);
      });
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read battery: $e');
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        _info = {
          'Model': '${info.brand} ${info.model}',
          'Manufacturer': info.manufacturer,
          'Android Version': info.version.release,
          'SDK': '${info.version.sdkInt}',
          'Hardware': info.hardware,
          'Device': info.device,
          'Product': info.product,
          'Board': info.board,
          'Fingerprint': info.fingerprint,
        };
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await _deviceInfo.windowsInfo;
        _info = {
          'OS': 'Windows ${info.majorVersion}.${info.minorVersion}',
          'Build': info.buildNumber.toString(),
          'Product Name': info.productName,
          'Build Lab': info.buildLab,
        };
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await _deviceInfo.linuxInfo;
        _info = {
          'OS': info.prettyName,
          'Version': info.version ?? '',
          'ID': info.id,
        };
      } else {
        _info = {'Platform': defaultTargetPlatform.name};
      }
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read device info: $e');
      _info = {'Error': e.toString()};
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Device Info')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_batteryLevel != null)
                    _BatteryCard(
                      level: _batteryLevel!,
                      isCharging:
                          _batteryState == BatteryState.charging ||
                          _batteryState == BatteryState.full,
                    ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._info.entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      entry.key,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withAlpha(150),
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  final int level;
  final bool isCharging;

  const _BatteryCard({required this.level, required this.isCharging});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = level > 60
        ? theme.colorScheme.primary
        : level > 20
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.battery_4_bar, size: 48, color: color),
                  Text(
                    '$level%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Battery',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$level% ${isCharging ? '(Charging)' : '(Not Charging)'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            Icon(isCharging ? Icons.bolt : Icons.battery_std, color: color),
          ],
        ),
      ),
    );
  }
}
