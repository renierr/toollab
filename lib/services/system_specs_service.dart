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
        };
      }
    } catch (_) {}
    return {};
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
