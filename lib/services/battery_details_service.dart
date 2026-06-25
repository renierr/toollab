import 'dart:io';
import 'package:flutter/services.dart';

class BatteryDetails {
  final double? voltage; // Volts
  final double? current; // Amperes
  final double? power; // Watts
  final bool isCharging;
  final String chargingSpeed; // 'slow', 'normal', 'fast', 'unknown'

  BatteryDetails({
    required this.voltage,
    required this.current,
    required this.power,
    required this.isCharging,
    required this.chargingSpeed,
  });

  factory BatteryDetails.unknown() {
    return BatteryDetails(
      voltage: null,
      current: null,
      power: null,
      isCharging: false,
      chargingSpeed: 'unknown',
    );
  }
}

class BatteryDetailsService {
  BatteryDetailsService._();

  static const _channel = MethodChannel('de.renier.tool_lab/battery_details');

  static Future<BatteryDetails> getBatteryDetails() async {
    if (Platform.isAndroid) {
      return _getAndroidBatteryDetails();
    } else if (Platform.isWindows) {
      return _getWindowsBatteryDetails();
    } else if (Platform.isLinux) {
      return _getLinuxBatteryDetails();
    }
    return BatteryDetails.unknown();
  }

  static Future<BatteryDetails> _getAndroidBatteryDetails() async {
    return _getBatteryDetailsFromChannel();
  }

  static Future<BatteryDetails> _getWindowsBatteryDetails() async {
    return _getBatteryDetailsFromChannel();
  }

  static Future<BatteryDetails> _getBatteryDetailsFromChannel() async {
    try {
      final Map<dynamic, dynamic>? res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getBatteryDetails');
      if (res == null) return BatteryDetails.unknown();

      final int voltageMilliVolts = res['voltage'] as int? ?? -1;
      final int currentMicroAmps = res['current'] as int? ?? 0;
      final bool isCharging = res['isCharging'] as bool? ?? false;

      final double? voltage = voltageMilliVolts > 0
          ? voltageMilliVolts / 1000.0
          : null;
      // Convert current from microamperes to Amperes.
      final double? current = currentMicroAmps != 0
          ? currentMicroAmps / 1000000.0
          : null;

      double? power;
      if (voltage != null && current != null) {
        power = (voltage * current).abs();
      }

      String chargingSpeed = 'unknown';
      if (isCharging) {
        if (power != null) {
          if (power >= 10.0) {
            chargingSpeed = 'fast';
          } else if (power < 4.5) {
            chargingSpeed = 'slow';
          } else {
            chargingSpeed = 'normal';
          }
        } else if (current != null) {
          final double absCurrent = current.abs();
          if (absCurrent >= 1.8) {
            chargingSpeed = 'fast';
          } else if (absCurrent < 0.8) {
            chargingSpeed = 'slow';
          } else {
            chargingSpeed = 'normal';
          }
        }
      }

      return BatteryDetails(
        voltage: voltage,
        current: current,
        power: power,
        isCharging: isCharging,
        chargingSpeed: chargingSpeed,
      );
    } catch (_) {
      return BatteryDetails.unknown();
    }
  }

  static Future<BatteryDetails> _getLinuxBatteryDetails() async {
    try {
      final Directory powerSupplyDir = Directory('/sys/class/power_supply');
      if (!await powerSupplyDir.exists()) {
        return BatteryDetails.unknown();
      }

      final List<FileSystemEntity> entities = await powerSupplyDir
          .list()
          .toList();
      Directory? batDir;
      for (final FileSystemEntity entity in entities) {
        if (entity is Directory) {
          final String name = entity.path.split('/').last;
          if (name.startsWith('BAT')) {
            batDir = entity;
            break;
          }
        }
      }

      if (batDir == null) {
        return BatteryDetails.unknown();
      }

      // Read status
      final File statusFile = File('${batDir.path}/status');
      bool isCharging = false;
      if (await statusFile.exists()) {
        final String status = (await statusFile.readAsString())
            .trim()
            .toLowerCase();
        isCharging = status == 'charging';
      }

      // Read power_now (microwatts) or voltage_now (microvolts) + current_now (microamperes)
      final File powerFile = File('${batDir.path}/power_now');
      final File voltageFile = File('${batDir.path}/voltage_now');
      final File currentFile = File('${batDir.path}/current_now');

      double? power;
      double? voltage;
      double? current;

      if (await powerFile.exists()) {
        final int? powerMicroWatts = int.tryParse(
          (await powerFile.readAsString()).trim(),
        );
        if (powerMicroWatts != null && powerMicroWatts != 0) {
          power = powerMicroWatts / 1000000.0;
        }
      }

      if (await voltageFile.exists()) {
        final int? voltageMicroVolts = int.tryParse(
          (await voltageFile.readAsString()).trim(),
        );
        if (voltageMicroVolts != null && voltageMicroVolts != 0) {
          voltage = voltageMicroVolts / 1000000.0;
        }
      }

      if (await currentFile.exists()) {
        final int? currentMicroAmps = int.tryParse(
          (await currentFile.readAsString()).trim(),
        );
        if (currentMicroAmps != null && currentMicroAmps != 0) {
          current = currentMicroAmps / 1000000.0;
        }
      }

      if (power == null && voltage != null && current != null) {
        power = voltage * current;
      }

      String chargingSpeed = 'unknown';
      if (isCharging) {
        if (power != null) {
          if (power >= 10.0) {
            chargingSpeed = 'fast';
          } else if (power < 4.5) {
            chargingSpeed = 'slow';
          } else {
            chargingSpeed = 'normal';
          }
        }
      }

      return BatteryDetails(
        voltage: voltage,
        current: current,
        power: power,
        isCharging: isCharging,
        chargingSpeed: chargingSpeed,
      );
    } catch (_) {
      return BatteryDetails.unknown();
    }
  }
}
