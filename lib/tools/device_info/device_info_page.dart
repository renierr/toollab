import 'dart:async';
import 'dart:io' show Platform, NetworkInterface, InternetAddressType;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/battery_details_service.dart';
import 'package:tool_lab/services/system_specs_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'package:tool_lab/theme/theme.dart';

import 'config.dart';
import 'widgets/battery_card.dart';
import 'widgets/info_card.dart';
import 'widgets/system_overview_header.dart';

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
  bool _hasLoaded = false;
  int? _batteryLevel;
  BatteryState? _batteryState;
  BatteryDetails? _batteryDetails;
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
  Map<String, String> _storageInfo = {};
  Map<String, String> _networkInfo = {};
  Map<String, String> _sensorsInfo = {};
  Map<String, String> _appInfo = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoaded) return;
    _hasLoaded = true;
    _loadAllInfo();
  }

  Future<void> _loadAllInfo() async {
    final l10n = AppLocalizations.of(context);
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      _batteryDetails = await BatteryDetailsService.getBatteryDetails();
      _batterySubscription = _battery.onBatteryStateChanged.listen((
        state,
      ) async {
        if (!mounted) return;
        final level = await _battery.batteryLevel;
        final details = await BatteryDetailsService.getBatteryDetails();
        setState(() {
          _batteryState = state;
          _batteryLevel = level;
          _batteryDetails = details;
        });
      });
      onDispose(() => _batterySubscription?.cancel());

      final timer = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted) return;
        final level = await _battery.batteryLevel;
        final state = await _battery.batteryState;
        final details = await BatteryDetailsService.getBatteryDetails();
        setState(() {
          _batteryLevel = level;
          _batteryState = state;
          _batteryDetails = details;
        });
      });
      onDispose(() => timer.cancel());
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

    // Fetch Storage and RAM
    try {
      final storage = await SystemSpecsService.getStorageInfo();
      final volumes = await SystemSpecsService.getStorageVolumes();
      final totalStorageGb = storage['total']! / (1024 * 1024 * 1024);
      final freeStorageGb = storage['free']! / (1024 * 1024 * 1024);
      final usedStorageGb = totalStorageGb - freeStorageGb;
      _storageInfo = {
        'Total Space': totalStorageGb > 0
            ? '${totalStorageGb.toStringAsFixed(2)} GB'
            : 'N/A',
        'Free Space': totalStorageGb > 0
            ? '${freeStorageGb.toStringAsFixed(2)} GB'
            : 'N/A',
        'Used Space': totalStorageGb > 0
            ? '${usedStorageGb.toStringAsFixed(2)} GB'
            : 'N/A',
      };

      final memory = await SystemSpecsService.getMemoryInfo();
      final totalMemoryGb = memory['total']! / (1024 * 1024 * 1024);
      final freeMemoryGb = memory['free']! / (1024 * 1024 * 1024);
      final usedMemoryGb = totalMemoryGb - freeMemoryGb;
      if (totalMemoryGb > 0) {
        _storageInfo['Total RAM'] = '${totalMemoryGb.toStringAsFixed(2)} GB';
        _storageInfo['Available RAM'] = '${freeMemoryGb.toStringAsFixed(2)} GB';
        _storageInfo['Used RAM'] = '${usedMemoryGb.toStringAsFixed(2)} GB';
      }
      for (final volume in volumes) {
        final total = volume['total'] as int? ?? 0;
        final free = volume['free'] as int? ?? 0;
        final name = volume['name'] as String?;
        if (name != null && total > 0) {
          _storageInfo[l10n.miscDeviceInfoStorageVolume(name)] =
              '${(free / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB / ${(total / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB ${l10n.miscDeviceInfoFree}';
        }
      }
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read storage/memory: $e');
    }

    // Fetch Network Info
    try {
      final Map<String, String> network = {};
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      if (interfaces.isEmpty) {
        network['Status'] = 'Disconnected';
      } else {
        network['Status'] = 'Connected';
        for (final interface in interfaces) {
          final name = interface.name.toLowerCase();
          String type = 'Other';
          if (name.contains('wlan') || name.contains('wifi')) {
            type = 'Wi-Fi';
          } else if (name.contains('eth')) {
            type = 'Ethernet';
          } else if (name.contains('rmnet') ||
              name.contains('ccmni') ||
              name.contains('ppp')) {
            type = 'Cellular';
          }
          final ips = interface.addresses
              .map((addr) => addr.address)
              .join(', ');
          if (ips.isNotEmpty) {
            network['${interface.name} ($type)'] = ips;
          }
        }
      }
      _networkInfo = network;
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read network: $e');
    }

    // Fetch Wi-Fi Info
    try {
      final wifi = await SystemSpecsService.getWifiInfo();
      if (wifi['ssid'] case final String ssid when ssid.isNotEmpty) {
        _networkInfo[l10n.miscDeviceInfoWifiSsid] = ssid;
      }
      if (wifi['signalPercent'] case final int signal when signal > 0) {
        _networkInfo[l10n.miscDeviceInfoWifiSignal] = '$signal%';
      } else if (wifi['rssi'] case final int rssi when rssi < 0) {
        _networkInfo[l10n.miscDeviceInfoWifiSignal] = '$rssi dBm';
      }
      if (wifi['linkSpeed'] case final int speed when speed > 0) {
        _networkInfo[l10n.miscDeviceInfoWifiLinkSpeed] = '$speed Mbps';
      }
      if (wifi['frequency'] case final int freq when freq > 0) {
        _networkInfo[l10n.miscDeviceInfoWifiFrequency] = freq > 2000
            ? '${(freq / 1000).toStringAsFixed(2)} GHz'
            : 'Ch $freq';
      }
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read wifi: $e');
    }

    // Fetch Sensors Info
    try {
      final sensors = await SystemSpecsService.getSensorInfo();
      final availability = await NfcManager.instance.checkAvailability();
      final String nfcStatus = availability == NfcAvailability.enabled
          ? 'Available'
          : (availability == NfcAvailability.disabled
                ? 'Disabled'
                : 'Not Supported');
      _sensorsInfo = {
        'Accelerometer': sensors['accelerometer']!
            ? 'Available'
            : 'Not Supported',
        'Gyroscope': sensors['gyroscope']! ? 'Available' : 'Not Supported',
        'Magnetometer': sensors['magnetometer']!
            ? 'Available'
            : 'Not Supported',
        'Barometer': sensors['barometer']! ? 'Available' : 'Not Supported',
        'Light Sensor': sensors['light']! ? 'Available' : 'Not Supported',
        'NFC': nfcStatus,
      };
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read sensors: $e');
    }

    // Fetch App Info
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appInfo = {
        'App Name': packageInfo.appName,
        'Package Name': packageInfo.packageName,
        'Version': packageInfo.version,
        'Build Number': packageInfo.buildNumber,
      };
    } catch (e) {
      debugPrint('[DeviceInfo] Failed to read app info: $e');
    }

    final (display, diagnostics) = await (
      SystemSpecsService.getDisplayInfo(),
      SystemSpecsService.getSystemDiagnostics(),
    ).wait;
    if (mounted) {
      final mediaQuery = MediaQuery.of(context);
      if (diagnostics['cpuModel'] case final String cpuModel
          when cpuModel.isNotEmpty) {
        _hardwareInfo[l10n.miscDeviceInfoCpuModel] = cpuModel;
      }
      if (diagnostics['cpuArchitecture'] case final String architecture
          when architecture.isNotEmpty) {
        _hardwareInfo[l10n.miscDeviceInfoCpuArchitecture] = architecture;
      }
      if (diagnostics['gpuModel'] case final String gpuModel
          when gpuModel.isNotEmpty) {
        _hardwareInfo[l10n.miscDeviceInfoGpuModel] = gpuModel;
      }
      if (diagnostics['gpuVramBytes'] case final int vram when vram > 0) {
        _hardwareInfo[l10n.miscDeviceInfoGpuVram] =
            '${(vram / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
      _displayInfo = {
        if (display['width'] != null && display['height'] != null)
          l10n.miscDeviceInfoWindowsDisplayResolution:
              '${display['width']} x ${display['height']} px',
        l10n.miscDeviceInfoAppViewSize:
            '${mediaQuery.size.width.round()} x ${mediaQuery.size.height.round()} pt',
        l10n.miscDeviceInfoAppViewPixels:
            '${(mediaQuery.size.width * mediaQuery.devicePixelRatio).round()} x ${(mediaQuery.size.height * mediaQuery.devicePixelRatio).round()} px',
        l10n.miscDeviceInfoDisplayScale:
            'x${mediaQuery.devicePixelRatio.toStringAsFixed(2)}',
        if (display['refreshRate'] case final int refreshRate
            when refreshRate > 0)
          l10n.miscDeviceInfoRefreshRate: '$refreshRate Hz',
        l10n.miscDeviceInfoOrientation: mediaQuery.orientation.name
            .toUpperCase(),
      };

      final now = DateTime.now();
      final offsetHours = now.timeZoneOffset.inHours;
      final offsetSign = offsetHours >= 0 ? '+' : '';
      _generalInfo = {
        'System Locale': Platform.localeName,
        'Time Zone': '${now.timeZoneName} (UTC $offsetSign$offsetHours)',
        'Dart Version': Platform.version.split(' ').first,
        if (diagnostics['uptimeSeconds'] case final int uptimeSeconds
            when uptimeSeconds > 0)
          (defaultTargetPlatform == TargetPlatform.windows
              ? l10n.miscDeviceInfoWindowsUptime
              : l10n.miscDeviceInfoSystemUptime): _formatUptime(
            l10n,
            uptimeSeconds,
          ),
      };

      setState(() => _loading = false);
    }
  }

  String _formatUptime(AppLocalizations l10n, int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inDays > 0) {
      return l10n.miscDeviceInfoUptimeDays(
        duration.inDays,
        duration.inHours.remainder(24),
      );
    }
    return l10n.miscDeviceInfoUptimeHours(
      duration.inHours,
      duration.inMinutes.remainder(60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ToolLayout(
      title: DeviceInfoTool.config.localizedName(l10n),
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
                    details: _batteryDetails,
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
                if (_storageInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InfoCard(
                    title: l10n.miscDeviceInfoStorage,
                    icon: Icons.storage_outlined,
                    accentColor: AppTheme.accentBlue,
                    items: _storageInfo,
                  ),
                ],
                if (_networkInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InfoCard(
                    title: l10n.miscDeviceInfoNetwork,
                    icon: Icons.wifi_outlined,
                    accentColor: AppTheme.accentGreen,
                    items: _networkInfo,
                  ),
                ],
                if (_sensorsInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InfoCard(
                    title: l10n.miscDeviceInfoSensors,
                    icon: Icons.sensors_outlined,
                    accentColor: AppTheme.accentTeal,
                    items: _sensorsInfo,
                  ),
                ],
                if (_appInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InfoCard(
                    title: l10n.miscDeviceInfoAppInfo,
                    icon: Icons.info_outline,
                    accentColor: AppTheme.accentPurple,
                    items: _appInfo,
                  ),
                ],
              ],
            ),
    );
  }
}
