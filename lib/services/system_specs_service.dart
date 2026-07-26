import 'dart:io';
import 'package:flutter/services.dart';

class SystemSpecsService {
  SystemSpecsService._();

  static const _channel = MethodChannel('de.renier.tool_lab/device_info');

  static Future<Map<String, int>> getStorageInfo() async {
    if (Platform.isAndroid || Platform.isWindows) {
      try {
        final Map<dynamic, dynamic>? res = await _channel
            .invokeMethod<Map<dynamic, dynamic>>('getStorageInfo');
        if (res != null) {
          return {
            'free': res['free'] as int? ?? 0,
            'total': res['total'] as int? ?? 0,
          };
        }
      } catch (_) {}
    } else if (Platform.isLinux) {
      return _getLinuxStorageInfo();
    }
    return {'free': 0, 'total': 0};
  }

  static Future<List<Map<String, dynamic>>> getStorageVolumes() async {
    if (Platform.isLinux) return _getLinuxStorageVolumes();
    if (!Platform.isAndroid && !Platform.isWindows) return [];

    try {
      final List<dynamic>? res = await _channel.invokeMethod<List<dynamic>>(
        'getStorageVolumes',
      );
      return res
              ?.whereType<Map<dynamic, dynamic>>()
              .map((volume) => volume.cast<String, dynamic>())
              .toList() ??
          [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getLinuxStorageVolumes() async {
    try {
      final result = await Process.run('df', [
        '-B1',
        '--output=target,size,avail',
      ]);
      if (result.exitCode != 0) return [];
      return result.stdout
          .toString()
          .split('\n')
          .skip(1)
          .map((line) => line.trim().split(RegExp(r'\s+')))
          .where((parts) => parts.length == 3)
          .map(
            (parts) => {
              'name': parts[0],
              'total': int.tryParse(parts[1]) ?? 0,
              'free': int.tryParse(parts[2]) ?? 0,
            },
          )
          .where((volume) => (volume['total'] as int) > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, int>> _getLinuxStorageInfo() async {
    try {
      final res = await Process.run('df', ['-B1', '/']);
      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final total = int.tryParse(parts[1]) ?? 0;
            final free = int.tryParse(parts[3]) ?? 0;
            return {'free': free, 'total': total};
          }
        }
      }
    } catch (_) {}
    return {'free': 0, 'total': 0};
  }

  static Future<Map<String, int>> getMemoryInfo() async {
    if (Platform.isAndroid || Platform.isLinux) {
      try {
        final file = File('/proc/meminfo');
        if (await file.exists()) {
          final lines = await file.readAsLines();
          int total = 0;
          int free = 0;
          for (final line in lines) {
            if (line.startsWith('MemTotal:')) {
              final parts = line.split(RegExp(r'\s+'));
              total =
                  (int.tryParse(parts[1]) ?? 0) * 1024; // convert kB to bytes
            } else if (line.startsWith('MemAvailable:')) {
              final parts = line.split(RegExp(r'\s+'));
              free =
                  (int.tryParse(parts[1]) ?? 0) * 1024; // convert kB to bytes
            }
          }
          if (total > 0) {
            return {'free': free, 'total': total};
          }
        }
      } catch (_) {}
    }
    return {'free': 0, 'total': 0};
  }

  static Future<Map<String, int>> getDisplayInfo() async {
    if (!Platform.isWindows) return {};

    try {
      final Map<dynamic, dynamic>? res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getDisplayInfo');
      if (res != null) {
        return {
          'width': res['width'] as int? ?? 0,
          'height': res['height'] as int? ?? 0,
          'refreshRate': res['refreshRate'] as int? ?? 0,
        };
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> getSystemDiagnostics() async {
    if (Platform.isLinux) return _getLinuxSystemDiagnostics();
    if (!Platform.isAndroid && !Platform.isWindows) return {};

    try {
      final Map<dynamic, dynamic>? res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getSystemDiagnostics');
      return res?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getLinuxSystemDiagnostics() async {
    try {
      final cpuInfo = await File('/proc/cpuinfo').readAsLines();
      final modelLine = cpuInfo.firstWhere(
        (line) => line.startsWith('model name') || line.startsWith('Hardware'),
        orElse: () => '',
      );
      final uptimeSeconds = double.tryParse(
        (await File('/proc/uptime').readAsString()).split(' ').first,
      );
      final architecture = (await Process.run('uname', [
        '-m',
      ])).stdout.toString().trim();

      // GPU via sysfs
      String gpuModel = '';
      int gpuVramBytes = 0;

      // Try NVIDIA proc entry first
      try {
        final nvidiaInfo = await File(
          '/proc/driver/nvidia/gpus/0/info',
        ).readAsLines();
        for (final line in nvidiaInfo) {
          if (line.startsWith('Model:')) {
            gpuModel = line.split(':').last.trim();
            break;
          }
        }
      } catch (_) {}

      if (gpuModel.isEmpty) {
        // Try AMD/Intel product_name from sysfs
        try {
          final drmDir = Directory('/sys/class/drm/');
          if (await drmDir.exists()) {
            final entries = await drmDir.list().toList();
            final cardDir = entries.firstWhere(
              (e) => e.path.contains('card') && !e.path.contains('-'),
              orElse: () => entries.isEmpty ? entries.first : entries.first,
            );
            if (cardDir is Directory) {
              final deviceDir = Directory('${cardDir.path}/device');
              if (await deviceDir.exists()) {
                final productName = File('${deviceDir.path}/product_name');
                if (await productName.exists()) {
                  gpuModel = (await productName.readAsString()).trim();
                }
                if (gpuModel.isEmpty) {
                  try {
                    final vendor = (await File(
                      '${deviceDir.path}/vendor',
                    ).readAsString()).trim();
                    final device = (await File(
                      '${deviceDir.path}/device',
                    ).readAsString()).trim();
                    gpuModel = 'GPU $vendor:$device';
                  } catch (_) {}
                }
                // VRAM
                try {
                  final vramFile = File(
                    '${deviceDir.path}/mem_info_vram_total',
                  );
                  if (await vramFile.exists()) {
                    gpuVramBytes =
                        int.tryParse((await vramFile.readAsString()).trim()) ??
                        0;
                  }
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }

      return {
        'cpuModel': modelLine.contains(':')
            ? modelLine.split(':').last.trim()
            : '',
        'cpuArchitecture': architecture,
        'uptimeSeconds': uptimeSeconds?.floor() ?? 0,
        'gpuModel': gpuModel,
        'gpuVramBytes': gpuVramBytes,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getWifiInfo() async {
    if (Platform.isAndroid) return _getAndroidWifiInfo();
    if (Platform.isWindows) return _getWindowsWifiInfo();
    if (Platform.isLinux) return _getLinuxWifiInfo();
    return {};
  }

  static Future<Map<String, dynamic>> _getAndroidWifiInfo() async {
    try {
      final Map<dynamic, dynamic>? res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getWifiInfo');
      return res?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getWindowsWifiInfo() async {
    try {
      final result = await Process.run('netsh', ['wlan', 'show', 'interfaces']);
      if (result.exitCode != 0) return {};
      final lines = result.stdout.toString().split('\n');
      String ssid = '';
      int signalPercent = 0;
      String bssid = '';
      int frequency = 0;
      int linkSpeed = 0;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('SSID') && trimmed.contains(':')) {
          final value = trimmed.split(':').last.trim();
          if (value.isNotEmpty && !value.contains(' ')) ssid = value;
        } else if (trimmed.startsWith('Signal') && trimmed.contains(':')) {
          final value = trimmed.split(':').last.trim().replaceAll('%', '');
          signalPercent = int.tryParse(value) ?? 0;
        } else if (trimmed.startsWith('BSSID') && trimmed.contains(':')) {
          bssid = trimmed.split(':').last.trim();
        } else if (trimmed.startsWith('Channel') && trimmed.contains(':')) {
          final value = trimmed.split(':').last.trim();
          frequency = int.tryParse(value) ?? 0;
        } else if (trimmed.startsWith('Receive rate') &&
            trimmed.contains(':')) {
          final value = trimmed.split(':').last.trim().split(' ').first;
          linkSpeed = double.tryParse(value)?.round() ?? 0;
        }
      }
      if (ssid.isEmpty) return {};
      return {
        'ssid': ssid,
        'bssid': bssid,
        'rssi': 0,
        'signalPercent': signalPercent,
        'frequency': frequency,
        'linkSpeed': linkSpeed,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getLinuxWifiInfo() async {
    try {
      // Find wireless interface from /proc/net/wireless
      final wireless = await File('/proc/net/wireless').readAsLines();
      if (wireless.length < 3) return {};
      final header = wireless[1].trim();
      if (!header.contains('Inter-|')) return {};
      final ifaceLine = wireless[2].trim();
      final iface = ifaceLine.split(':').first.trim();
      if (iface.isEmpty) return {};
      // Parse /proc/net/wireless for signal
      final parts = ifaceLine.split(RegExp(r'\s+'));
      final linkQuality = int.tryParse(parts[2]) ?? 0;
      final signalLevel = int.tryParse(parts[3]) ?? 0;
      // RSSI in dBm: typically signalLevel is in dBm for most drivers
      int rssi = signalLevel;
      int signalPercent = (linkQuality / 70.0 * 100).clamp(0, 100).round();
      // Query SSID via iw
      final iwResult = await Process.run('iw', ['dev', iface, 'link']);
      String ssid = '';
      int frequency = 0;
      int linkSpeed = 0;
      if (iwResult.exitCode == 0) {
        for (final line in iwResult.stdout.toString().split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('SSID:')) {
            ssid = trimmed.split(':').last.trim();
          } else if (trimmed.startsWith('freq:')) {
            final value = trimmed.split(':').last.trim();
            frequency = double.tryParse(value)?.round() ?? 0;
          } else if (trimmed.startsWith('signal:')) {
            final value = trimmed.split(':').last.trim().split(' ').first;
            final iwRssi = double.tryParse(value);
            if (iwRssi != null) {
              rssi = iwRssi.round();
              signalPercent = (100 + rssi).clamp(0, 100);
            }
          } else if (trimmed.startsWith('tx bitrate:')) {
            final value = trimmed.split(':').last.trim().split(' ').first;
            linkSpeed = double.tryParse(value)?.round() ?? 0;
          }
        }
      }
      if (ssid.isEmpty) return {};
      return {
        'ssid': ssid,
        'bssid': '',
        'rssi': rssi,
        'signalPercent': signalPercent,
        'frequency': frequency,
        'linkSpeed': linkSpeed,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, bool>> getSensorInfo() async {
    if (Platform.isAndroid || Platform.isWindows) {
      try {
        final Map<dynamic, dynamic>? res = await _channel
            .invokeMethod<Map<dynamic, dynamic>>('getSensorInfo');
        if (res != null) {
          return {
            'accelerometer': res['accelerometer'] as bool? ?? false,
            'gyroscope': res['gyroscope'] as bool? ?? false,
            'magnetometer': res['magnetometer'] as bool? ?? false,
            'barometer': res['barometer'] as bool? ?? false,
            'light': res['light'] as bool? ?? false,
          };
        }
      } catch (_) {}
    }
    return {
      'accelerometer': false,
      'gyroscope': false,
      'magnetometer': false,
      'barometer': false,
      'light': false,
    };
  }
}
