import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'location_source.dart';

/// Outcome of a location capture attempt.
class LocationFix {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final LocationSource source;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.source,
  });
}

/// Raised when neither precise GPS nor IP-based approximation succeed.
class LocationUnavailableException implements Exception {
  final String message;
  const LocationUnavailableException(this.message);
  @override
  String toString() => message;
}

/// Captures the current device position, preferring precise GPS and
/// transparently falling back to a coarse IP-based estimate.
class LocationCaptureService {
  LocationCaptureService._();

  static const String _ipEndpoint = 'https://ipapi.co/json/';

  /// Attempts a precise GPS fix first; on failure falls back to IP geolocation.
  /// Throws [LocationUnavailableException] if both fail.
  static Future<LocationFix> capture() async {
    final gps = await _tryGps();
    if (gps != null) return gps;

    final ip = await _tryIp();
    if (ip != null) return ip;

    throw const LocationUnavailableException(
      'Could not determine a precise or approximate position.',
    );
  }

  static Future<LocationFix?> _tryGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        source: LocationSource.gps,
      );
    } catch (e) {
      debugPrint('[LocationCaptureService] GPS fix failed: $e');
      return null;
    }
  }

  static Future<LocationFix?> _tryIp() async {
    try {
      final response = await http
          .get(Uri.parse(_ipEndpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lon = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      return LocationFix(
        latitude: lat,
        longitude: lon,
        accuracy: null,
        source: LocationSource.ip,
      );
    } catch (e) {
      debugPrint('[LocationCaptureService] IP fix failed: $e');
      return null;
    }
  }
}
