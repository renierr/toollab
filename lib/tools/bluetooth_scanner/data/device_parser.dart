import 'package:universal_ble/universal_ble.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'scanned_device.dart';
import 'service_uuids.dart';
import 'manufacturer_ids.dart';
import 'device_patterns.dart';
import 'beacon_detector.dart';
import 'environmental_reading.dart';
import 'xiaomi_sensor_parser.dart';

class DeviceParser {
  static ScannedDevice parseBleDevice(
    BleDevice device,
    ScannedDevice? existing,
  ) {
    final name = (device.name ?? '').isNotEmpty ? device.name! : 'Unknown';
    final deviceInfo = matchDevicePattern(name);

    final services = device.services;
    final serviceUuidShort = services
        .map((u) => u.toLowerCase().replaceAll('-', ''))
        .toList();

    final serviceNames = <String>[];
    for (final uuid in serviceUuidShort) {
      final sn = getServiceName(uuid);
      serviceNames.add(
        sn ?? '0x${uuid.length >= 4 ? uuid.substring(0, 4) : uuid}',
      );
    }

    final matchedFilters = getMatchingServiceFilters(services);

    final mfrDataMap = <int, List<int>>{};
    for (final mfrData in device.manufacturerDataList) {
      mfrDataMap[mfrData.companyId] = mfrData.payload.toList();
    }

    final serviceDataMap = <String, List<int>>{};
    for (final entry in device.serviceData.entries) {
      serviceDataMap[entry.key] = entry.value.toList();
    }

    final beacons = detectBeacons(
      serviceUuids: services,
      serviceData: serviceDataMap,
      manufacturerData: mfrDataMap,
    );

    final mfrName = _deriveManufacturer(
      deviceInfo: deviceInfo,
      manufacturerData: mfrDataMap,
    );
    final mfrIsKnownName =
        deviceInfo?.manufacturer != null ||
        mfrDataMap.keys.any((k) => getManufacturerName(k) != null);

    final identifiedType =
        deviceInfo?.type ??
        (beacons.isNotEmpty ? beacons.first.type : 'Unknown');
    final identifiedCategory = beacons.isNotEmpty
        ? 'Beacon'
        : (deviceInfo?.category ?? 'Unknown');
    final likelyRole = _deriveRole(identifiedCategory, matchedFilters, beacons);
    final confidenceResult = _calculateConfidence(
      hasKnownDevice: deviceInfo != null,
      hasManufacturer: mfrIsKnownName,
      hasManufacturerData: mfrDataMap.isNotEmpty,
      matchedFilterCount: matchedFilters.length,
      serviceCount: serviceNames.length,
      beaconCount: beacons.length,
      isPaired: device.paired == true,
    );

    final fingerprint = _createFingerprint(
      manufacturer: mfrName,
      category: identifiedCategory,
      type: identifiedType,
      beacons: beacons,
      filters: matchedFilters,
    );

    final hints = <String>[];
    if (mfrIsKnownName) {
      hints.add('Manufacturer $mfrName');
    } else if (mfrDataMap.isNotEmpty) {
      hints.add('Raw mfr $mfrName');
    }
    for (final b in beacons) {
      hints.add('Beacon ${b.type}');
    }
    for (final f in matchedFilters.take(2)) {
      hints.add('Service profile ${f.replaceAll('_', ' ')}');
    }
    if (serviceNames.isNotEmpty) hints.add('Advertises ${serviceNames.first}');

    final mfrDataStrings = <int, String>{};
    for (final entry in mfrDataMap.entries) {
      mfrDataStrings[entry.key] = entry.value
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
    }

    final serviceDataStrings = <String, String>{};
    for (final entry in serviceDataMap.entries) {
      serviceDataStrings[entry.key] = entry.value
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
    }

    final sensorData = _mergeEnvironmental(
      existing: existing?.sensorData,
      incoming: XiaomiSensorParser.parse(serviceDataMap, mfrDataMap),
    );

    final mergedServiceUuids = serviceUuidShort.isNotEmpty
        ? serviceUuidShort
        : (existing?.serviceUuids ?? const <String>[]);
    final mergedServiceNames = serviceNames.isNotEmpty
        ? serviceNames
        : (existing?.serviceNames ?? const <String>[]);
    final mergedManufacturerData = mfrDataStrings.isNotEmpty
        ? mfrDataStrings
        : existing?.manufacturerData;
    final mergedServiceDataRaw = serviceDataStrings.isNotEmpty
        ? serviceDataStrings
        : existing?.serviceDataRaw;

    return ScannedDevice(
      id: device.deviceId,
      name: name,
      knownName: deviceInfo?.name,
      rssi: device.rssi ?? 0,
      manufacturer: mfrName,
      identifiedType: identifiedType,
      identifiedCategory: identifiedCategory,
      likelyRole: likelyRole,
      fingerprint: fingerprint,
      confidence: confidenceResult.level,
      confidenceReasons: confidenceResult.reasons,
      serviceUuids: mergedServiceUuids,
      serviceNames: mergedServiceNames,
      matchedFilters: matchedFilters,
      beacons: beacons,
      hints: hints,
      manufacturerData: mergedManufacturerData,
      serviceDataRaw: mergedServiceDataRaw,
      paired: device.paired,
      isSystemDevice: device.isSystemDevice,
      sensorData: sensorData,
    );
  }

  static ScannedDevice parseClassicDevice(BtcDevice device) {
    final name = (device.name?.isNotEmpty ?? false) ? device.name! : 'Unknown';
    final deviceInfo = matchDevicePattern(name);

    final isPaired = device.bondState == BtcBondState.bonded;
    final confidenceResult = _calculateConfidence(
      hasKnownDevice: deviceInfo != null,
      hasManufacturer: false,
      hasManufacturerData: false,
      matchedFilterCount: 0,
      serviceCount: 0,
      beaconCount: 0,
      isPaired: isPaired,
    );

    final hints = <String>['Classic Bluetooth'];
    if (deviceInfo != null) {
      hints.add('Known device pattern');
    }
    if (isPaired) {
      hints.add('Paired');
    }

    return ScannedDevice(
      id: device.address,
      name: name,
      knownName: deviceInfo?.name,
      rssi: 0,
      manufacturer: deviceInfo?.manufacturer,
      identifiedType: deviceInfo?.type ?? 'Unknown',
      identifiedCategory: deviceInfo?.category ?? 'Classic',
      likelyRole: deviceInfo?.name ?? 'Classic Device',
      fingerprint: 'classic-${device.address.replaceAll(':', '')}',
      confidence: confidenceResult.level,
      confidenceReasons: confidenceResult.reasons,
      hints: hints,
      paired: isPaired,
      transport: Transport.classic,
    );
  }

  static String? _deriveManufacturer({
    DevicePattern? deviceInfo,
    required Map<int, List<int>> manufacturerData,
  }) {
    if (deviceInfo != null && deviceInfo.manufacturer != null) {
      return deviceInfo.manufacturer!;
    }
    for (final entry in manufacturerData.entries) {
      final name = getManufacturerName(entry.key);
      if (name != null) {
        return name;
      }
    }
    if (manufacturerData.isNotEmpty) {
      return '0x${manufacturerData.keys.first.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    }
    return null;
  }

  static String _deriveRole(
    String category,
    List<String> filters,
    List<BeaconInfo> beacons,
  ) {
    if (beacons.isNotEmpty) return 'Beacon';
    if (filters.contains('heart_rate')) return 'Health Sensor';
    if (filters.contains('audio')) return 'Audio Device';
    if (category == 'Wearables') return 'Wearable';
    if (category == 'IoT') return 'IoT Device';
    if (category == 'Unknown') return 'Unclassified Device';
    return category;
  }

  static ({Confidence level, List<String> reasons}) _calculateConfidence({
    required bool hasKnownDevice,
    required bool hasManufacturer,
    required bool hasManufacturerData,
    required int matchedFilterCount,
    required int serviceCount,
    required int beaconCount,
    required bool isPaired,
  }) {
    int score = 0;
    final reasons = <String>[];

    if (hasKnownDevice) {
      score += 4;
      reasons.add('Known device pattern');
    }
    if (hasManufacturer) {
      score += 2;
      reasons.add('Known manufacturer');
    } else if (hasManufacturerData) {
      score += 1;
      reasons.add('Raw manufacturer data');
    }
    if (matchedFilterCount > 0) {
      score += 1;
      reasons.add('Service profile match');
    }
    if (serviceCount > 0) {
      score += 1;
      reasons.add('Advertised service');
    }
    if (beaconCount > 0) {
      score += 3;
      reasons.add('Beacon signature parsed');
    }
    if (isPaired) {
      score += 2;
      reasons.add('Previously paired');
    }

    return (
      level: score >= 6
          ? Confidence.high
          : (score >= 3 ? Confidence.medium : Confidence.low),
      reasons: reasons,
    );
  }

  static String _createFingerprint({
    String? manufacturer,
    required String category,
    required String type,
    required List<BeaconInfo> beacons,
    required List<String> filters,
  }) {
    final parts = [
      manufacturer ?? 'unknown-mfr',
      category,
      type,
      beacons.map((b) => b.type).join('|'),
      filters.join('|'),
    ];
    final input = parts.join('::');
    return 'fp-${_hashString(input)}';
  }

  static String _hashString(String value) {
    int hash = 5381;
    for (int i = 0; i < value.length; i++) {
      hash = ((hash << 5) + hash) ^ value.codeUnitAt(i);
    }
    return (hash & 0xFFFFFFFF).toRadixString(16);
  }

  static EnvironmentalReading? _mergeEnvironmental({
    required EnvironmentalReading? existing,
    required EnvironmentalReading? incoming,
  }) {
    if (existing == null) return incoming;
    if (incoming == null) return existing;
    return EnvironmentalReading(
      temperatureCelsius:
          incoming.temperatureCelsius ?? existing.temperatureCelsius,
      humidityPercent: incoming.humidityPercent ?? existing.humidityPercent,
      batteryPercent: incoming.batteryPercent ?? existing.batteryPercent,
    );
  }
}
