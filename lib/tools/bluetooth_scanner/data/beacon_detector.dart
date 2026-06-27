import 'scanned_device.dart';

class BeaconDefinition {
  final String type;
  final String format;

  const BeaconDefinition({required this.type, required this.format});
}

const Map<String, BeaconDefinition> beaconTypes = {
  'apple_ibeacon': BeaconDefinition(
    type: 'iBeacon',
    format: 'Apple iBeacon (UUID + Major + Minor)',
  ),
  'eddystone_uid': BeaconDefinition(
    type: 'Eddystone UID',
    format: 'Google Eddystone UID (Namespace + Instance)',
  ),
  'eddystone_url': BeaconDefinition(
    type: 'Eddystone URL',
    format: 'Google Eddystone URL',
  ),
  'eddystone_tlm': BeaconDefinition(
    type: 'Eddystone TLM',
    format: 'Google Eddystone TLM (Telemetry)',
  ),
  'eddystone_eid': BeaconDefinition(
    type: 'Eddystone EID',
    format: 'Google Eddystone EID (Ephemeral ID)',
  ),
  'altbeacon': BeaconDefinition(
    type: 'AltBeacon',
    format: 'Open Beacon format',
  ),
  'ruuvi': BeaconDefinition(
    type: 'RuuviTag',
    format: 'Environmental sensor data',
  ),
};

List<BeaconInfo> detectBeacons({
  required List<String> serviceUuids,
  required Map<String, List<int>> serviceData,
  required Map<int, List<int>> manufacturerData,
}) {
  final detected = <BeaconInfo>[];
  final normalizedUuids = serviceUuids
      .map((u) => u.toLowerCase().replaceAll('-', ''))
      .toSet();

  // Eddystone (service UUID 0xFEAA)
  if (normalizedUuids.contains('feaa')) {
    final frameType = _getEddystoneFrameType(serviceData);
    final details = _parseEddystoneDetails(serviceData);
    final key = switch (frameType) {
      0x00 => 'eddystone_uid',
      0x10 => 'eddystone_url',
      0x20 => 'eddystone_tlm',
      0x30 => 'eddystone_eid',
      _ => 'eddystone_uid',
    };
    final def = beaconTypes[key];
    if (def != null) {
      detected.add(
        BeaconInfo(type: def.type, format: def.format, details: details),
      );
    }
  }

  // iBeacon (Apple manufacturer 0x004C with prefix 02 15)
  for (final entry in manufacturerData.entries) {
    if (entry.key == 0x004c && _hasIBeaconPrefix(entry.value)) {
      final details = _parseIBeaconDetails(entry.value);
      detected.add(
        BeaconInfo(
          type: 'iBeacon',
          format: beaconTypes['apple_ibeacon']!.format,
          details: details,
        ),
      );
    }

    // RuuviTag (manufacturer 0x0499)
    if (entry.key == 0x0499) {
      final details = _parseRuuviDetails(entry.value);
      detected.add(
        BeaconInfo(
          type: 'RuuviTag',
          format: beaconTypes['ruuvi']!.format,
          details: details,
        ),
      );
    }

    // AltBeacon (prefix BE AC)
    if (entry.value.length >= 2 &&
        entry.value[0] == 0xbe &&
        entry.value[1] == 0xac) {
      final details = _parseAltBeaconDetails(entry.value);
      detected.add(
        BeaconInfo(
          type: 'AltBeacon',
          format: beaconTypes['altbeacon']!.format,
          details: details,
        ),
      );
    }
  }

  return detected;
}

int? _getEddystoneFrameType(Map<String, List<int>> serviceData) {
  for (final entry in serviceData.entries) {
    final uuid = entry.key.toLowerCase().replaceAll('-', '');
    if (uuid.contains('feaa') && entry.value.isNotEmpty) {
      return entry.value[0];
    }
  }
  return null;
}

List<String> _parseEddystoneDetails(Map<String, List<int>> serviceData) {
  for (final entry in serviceData.entries) {
    final uuid = entry.key.toLowerCase().replaceAll('-', '');
    if (!uuid.contains('feaa') || entry.value.length < 2) continue;

    final data = entry.value;
    final frameType = data[0];
    final txPower = data.length > 1 ? _toSigned(data[1]) : 0;

    if (frameType == 0x00 && data.length >= 18) {
      final namespace = _hexBytes(data, 2, 10);
      final instance = _hexBytes(data, 12, 6);
      return ['Tx $txPower dBm', 'Namespace $namespace', 'Instance $instance'];
    }

    if (frameType == 0x10 && data.length >= 3) {
      final url = _decodeEddystoneUrl(data);
      return url != null
          ? ['Tx $txPower dBm', 'URL $url']
          : ['Tx $txPower dBm'];
    }

    if (frameType == 0x20 && data.length >= 14) {
      final battery = (data[2] << 8) | data[3];
      final temp = _toSigned(data[4]) + data[5] / 256.0;
      final advCount =
          (data[6] << 24) | (data[7] << 16) | (data[8] << 8) | data[9];
      return [
        'Battery $battery mV',
        'Temp ${temp.toStringAsFixed(2)} C',
        'Adv $advCount',
      ];
    }

    if (frameType == 0x30 && data.length >= 10) {
      final eid = _hexBytes(data, 2, 8);
      return ['EID $eid'];
    }
  }
  return [];
}

String? _decodeEddystoneUrl(List<int> data) {
  if (data.length < 3) return null;
  const prefixes = {
    0x00: 'http://www.',
    0x01: 'https://www.',
    0x02: 'http://',
    0x03: 'https://',
  };
  const suffixes = {
    0x00: '.com/',
    0x01: '.org/',
    0x02: '.edu/',
    0x03: '.net/',
    0x04: '.info/',
    0x05: '.biz/',
    0x06: '.gov/',
    0x07: '.com',
    0x08: '.org',
    0x09: '.edu',
    0x0a: '.net',
    0x0b: '.info',
    0x0c: '.biz',
    0x0d: '.gov',
  };

  final sb = StringBuffer(prefixes[data[2]] ?? '');
  for (int i = 3; i < data.length; i++) {
    final v = data[i];
    sb.write(suffixes[v] ?? String.fromCharCode(v));
  }
  final url = sb.toString();
  return url.isEmpty ? null : url;
}

List<String> _parseIBeaconDetails(List<int> data) {
  if (data.length < 23 || !_hasIBeaconPrefix(data)) return [];
  final rawUuid = _hexBytes(data, 2, 16);
  final uuid =
      '${rawUuid.substring(0, 8)}-${rawUuid.substring(8, 12)}-'
      '${rawUuid.substring(12, 16)}-${rawUuid.substring(16, 20)}-'
      '${rawUuid.substring(20)}';
  final major = (data[18] << 8) | data[19];
  final minor = (data[20] << 8) | data[21];
  final txPower = _toSigned(data[22]);
  return ['UUID $uuid', 'Major $major', 'Minor $minor', 'Tx $txPower dBm'];
}

List<String> _parseAltBeaconDetails(List<int> data) {
  if (data.length < 24) return [];
  final beaconId = _hexBytes(data, 2, 20);
  final refRssi = _toSigned(data[22]);
  return ['ID $beaconId', 'Ref RSSI $refRssi dBm'];
}

List<String> _parseRuuviDetails(List<int> data) {
  if (data.isEmpty) return [];
  final format = data[0];
  final details = ['Format 0x${format.toRadixString(16).padLeft(2, '0')}'];
  if (format == 0x05 && data.length >= 3) {
    final tempRaw = (data[1] << 8) | data[2];
    if (tempRaw > 32767) {
      details.add('Temp ${((tempRaw - 65536) * 0.005).toStringAsFixed(2)} C');
    } else {
      details.add('Temp ${(tempRaw * 0.005).toStringAsFixed(2)} C');
    }
  }
  return details;
}

bool _hasIBeaconPrefix(List<int> data) {
  return data.length >= 2 && data[0] == 0x02 && data[1] == 0x15;
}

int _toSigned(int value) => value > 127 ? value - 256 : value;

String _hexBytes(List<int> data, int start, int length) {
  final sb = StringBuffer();
  for (int i = 0; i < length && start + i < data.length; i++) {
    sb.write(data[start + i].toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
