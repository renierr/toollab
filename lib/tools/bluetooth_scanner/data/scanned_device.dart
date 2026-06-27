enum Confidence { low, medium, high }

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
  final DateTime timestamp;

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
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
