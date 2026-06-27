import 'dart:math';
import 'environmental_reading.dart';

enum Confidence { low, medium, high }

enum Transport { ble, classic }

class BeaconInfo {
  final String type;
  final String format;
  final List<String> details;

  const BeaconInfo({
    required this.type,
    required this.format,
    this.details = const [],
  });
}

class ScannedDevice {
  final String id;
  final String name;
  final String? knownName;
  final int rssi;
  final String? manufacturer;
  final String identifiedType;
  final String identifiedCategory;
  final String likelyRole;
  final String fingerprint;
  final Confidence confidence;
  final List<String> confidenceReasons;
  final List<String> serviceUuids;
  final List<String> serviceNames;
  final List<String> matchedFilters;
  final List<BeaconInfo> beacons;
  final List<String> hints;
  final Map<int, String>? manufacturerData;
  final int? txPower;
  final bool? paired;
  final bool? isSystemDevice;
  final EnvironmentalReading? sensorData;
  final Map<String, String>? serviceDataRaw;
  final Transport transport;
  final DateTime timestamp;

  double? get estimatedDistance {
    if (rssi >= 0) return null;
    final tx = (txPower ?? -59).toDouble();
    return pow(10, (tx - rssi) / 20.0).toDouble();
  }

  ScannedDevice({
    required this.id,
    required this.name,
    this.knownName,
    required this.rssi,
    this.manufacturer,
    this.identifiedType = 'Unknown',
    this.identifiedCategory = 'Unknown',
    this.likelyRole = 'Unclassified Device',
    required this.fingerprint,
    this.confidence = Confidence.low,
    this.confidenceReasons = const [],
    this.serviceUuids = const [],
    this.serviceNames = const [],
    this.matchedFilters = const [],
    this.beacons = const [],
    this.hints = const [],
    this.manufacturerData,
    this.txPower,
    this.paired,
    this.isSystemDevice,
    this.sensorData,
    this.serviceDataRaw,
    this.transport = Transport.ble,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
