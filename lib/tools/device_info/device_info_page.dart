import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/theme/theme.dart';

import 'config.dart';
import 'battery_card.dart';
import 'info_card.dart';
import 'system_overview_header.dart';

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage>
    with DisposeCleanup<DeviceInfoPage> {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Battery _battery = Battery();

  bool _loading = true;
  int? _batteryLevel;
  BatteryState? _batteryState;
  final bool _isBatterySaver = false;
  StreamSubscription<BatteryState>? _batterySubscription;

  String _osName = '';
  String _osVersion = '';
  String _deviceName = '';
  String _modelName = '';

  Map<String, String> _systemInfo = {};
  Map<String, String> _hardwareInfo = {};
  Map<String, String> _displayInfo = {};
  Map<String, String> _generalInfo = {};

  @override
  void initState() {
    super.initState();
    _loadAllInfo();
  }

  Future<void> _loadAllInfo() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      _batterySubscription = _battery.onBatteryStateChanged.listen((
        state,
      ) async {
        if (!mounted) return;
        final level = await _battery.batteryLevel;
        setState(() {
          _batteryState = state;
          _batteryLevel = level;
        });
      });
      onDispose(() => _batterySubscription?.cancel());
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read battery: $e');
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;

        _osName = 'Android';
        _osVersion = '${info.version.release} (API ${info.version.sdkInt})';
        _deviceName = info.device;
        _modelName = '${info.brand} ${info.model}';

        _systemInfo = {
          'OS': 'Android',
          'OS Version': info.version.release,
          'SDK Version': '${info.version.sdkInt}',
          'Security Patch': info.version.securityPatch ?? 'N/A',
          'Build ID': info.id,
          'Fingerprint': info.fingerprint,
        };

        _hardwareInfo = {
          'Brand / Manufacturer': '${info.brand} / ${info.manufacturer}',
          'Model': info.model,
          'Board / Motherboard': '${info.board} / ${info.hardware}',
          'Bootloader': info.bootloader,
          'CPU Cores': '${Platform.numberOfProcessors}',
          'Supported ABIs': info.supportedAbis.take(3).join(', '),
          'Hardware Name': info.hardware,
          'Physical Device': info.isPhysicalDevice ? 'Yes' : 'No (Emulator)',
        };
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await _deviceInfo.windowsInfo;

        _osName = info.productName.isNotEmpty ? info.productName : 'Windows';
        _osVersion = info.displayVersion.isNotEmpty
            ? info.displayVersion
            : 'Build ${info.buildNumber}';
        _deviceName = info.computerName;
        _modelName = info.productName;

        _systemInfo = {
          'OS Product': info.productName,
          'Edition': info.editionId,
          'OS Version': 'Windows ${info.majorVersion}.${info.minorVersion}',
          'Build Number': '${info.buildNumber}',
          'Build Lab': info.buildLab,
          'Registry ID': info.deviceId,
        };

        _hardwareInfo = {
          'Computer Name': info.computerName,
          'User Name': info.userName,
          'CPU Cores': '${info.numberOfCores}',
          'System RAM':
              '${(info.systemMemoryInMegabytes / 1024).toStringAsFixed(2)} GB',
          'Install Date': FormatHelper.dateTime(
            info.installDate.toLocal(),
            style: DateStyle.dateTimeSeconds,
          ),
        };
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await _deviceInfo.linuxInfo;

        _osName = info.prettyName;
        _osVersion = info.version ?? 'Unknown';
        _deviceName = Platform.localHostname;
        _modelName = 'Linux Device';

        _systemInfo = {
          'Distribution': info.name,
          'Pretty Name': info.prettyName,
          'OS Version': info.version ?? 'N/A',
          'ID': info.id,
          'Kernel Version': Platform.operatingSystemVersion,
        };

        _hardwareInfo = {
          'Local Hostname': Platform.localHostname,
          'CPU Cores': '${Platform.numberOfProcessors}',
        };
      } else {
        _osName = defaultTargetPlatform.name;
        _osVersion = Platform.operatingSystemVersion;
        _deviceName = Platform.localHostname;
        _modelName = 'Generic Device';

        _systemInfo = {
          'Platform': defaultTargetPlatform.name,
          'OS Version': Platform.operatingSystemVersion,
        };
        _hardwareInfo = {'Cores': '${Platform.numberOfProcessors}'};
      }
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read device info: $e');
      _systemInfo = {'Error': e.toString()};
    }

    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      _displayInfo = {
        'Screen Size':
            '${mediaQuery.size.width.round()} x ${mediaQuery.size.height.round()} pt',
        'Physical Pixels':
            '${(mediaQuery.size.width * mediaQuery.devicePixelRatio).round()} x ${(mediaQuery.size.height * mediaQuery.devicePixelRatio).round()} px',
        'Device Pixel Ratio':
            'x${mediaQuery.devicePixelRatio.toStringAsFixed(2)}',
        'Orientation': mediaQuery.orientation.name.toUpperCase(),
      };

      final now = DateTime.now();
      final offsetHours = now.timeZoneOffset.inHours;
      final offsetSign = offsetHours >= 0 ? '+' : '';
      _generalInfo = {
        'System Locale': Platform.localeName,
        'Time Zone': '${now.timeZoneName} (UTC $offsetSign$offsetHours)',
        'Dart Version': Platform.version.split(' ').first,
      };

      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ToolLayout(
      title: DeviceInfoTool.config.name,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                SystemOverviewHeader(
                  osName: _osName,
                  osVersion: _osVersion,
                  deviceName: _deviceName,
                  modelName: _modelName,
                ),
                const SizedBox(height: 20),
                if (_batteryLevel != null && _batteryState != null) ...[
                  BatteryCard(
                    level: _batteryLevel!,
                    state: _batteryState!,
                    isSaverMode: _isBatterySaver,
                  ),
                  const SizedBox(height: 12),
                ],
                InfoCard(
                  title: l10n.miscDeviceInfoSystemOs,
                  icon: Icons.settings_applications_outlined,
                  accentColor: AppTheme.accentPurple,
                  items: _systemInfo,
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: l10n.miscDeviceInfoHardwareSpecs,
                  icon: Icons.memory_outlined,
                  accentColor: AppTheme.accentBlue,
                  items: _hardwareInfo,
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: l10n.miscDeviceInfoDisplayDetails,
                  icon: Icons.screenshot_outlined,
                  accentColor: AppTheme.accentTeal,
                  items: _displayInfo,
                ),
                const SizedBox(height: 12),
                InfoCard(
                  title: l10n.miscDeviceInfoGeneralSettings,
                  icon: Icons.public_outlined,
                  accentColor: AppTheme.accentAmber,
                  items: _generalInfo,
                ),
              ],
            ),
    );
  }
}
