import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:tool_lab/helpers/debug_log.dart';

class DeviceFix {
  const DeviceFix(this.latitude, this.longitude, this.altitude);

  final double latitude;
  final double longitude;
  final double? altitude;
}

enum DeviceLocationError { unsupported, serviceDisabled, denied, failed }

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.error);

  final DeviceLocationError error;
}

class WeatherDeviceLocation {
  WeatherDeviceLocation._();

  static bool get isSupported =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  /// [mayPrompt] must be false where no Activity exists (background runs).
  static Future<DeviceFix> current({required bool mayPrompt}) async {
    if (!isSupported) {
      throw const DeviceLocationException(DeviceLocationError.unsupported);
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const DeviceLocationException(
          DeviceLocationError.serviceDisabled,
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && mayPrompt) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const DeviceLocationException(DeviceLocationError.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return DeviceFix(
        position.latitude,
        position.longitude,
        position.altitude == 0 ? null : position.altitude,
      );
    } on DeviceLocationException {
      rethrow;
    } catch (e) {
      errorLog('[WeatherDeviceLocation] fix failed: $e');
      throw const DeviceLocationException(DeviceLocationError.failed);
    }
  }
}
