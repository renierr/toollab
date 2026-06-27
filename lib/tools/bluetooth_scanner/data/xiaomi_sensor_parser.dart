import 'environmental_reading.dart';

class XiaomiSensorParser {
  static EnvironmentalReading? parse(
    Map<String, List<int>> serviceData,
    Map<int, List<int>> manufacturerData,
  ) {
    for (final entry in serviceData.entries) {
      final uuid = entry.key.toLowerCase().replaceAll('-', '');
      if (!uuid.contains('fe95')) continue;
      final data = entry.value;
      if (data.length < 5) continue;

      final result = _parseSensorData(data);
      if (result != null) return result;
    }
    return null;
  }

  static EnvironmentalReading? _parseSensorData(List<int> data) {
    if (data.length < 5) return null;

    var result = _parseMiBeaconHeader(data, 0);
    result ??= _parseMiBeaconHeader(data, 1);
    return result;
  }

  static EnvironmentalReading? _parseMiBeaconHeader(List<int> data, int order) {
    int frameControl;
    int offset;

    if (order == 0) {
      // 2-byte frame control big-endian: data[0] << 8 | data[1]
      frameControl = (data[0] << 8) | data[1];
      offset = 4;
    } else {
      // 1-byte frame control: data[0]
      frameControl = data[0];
      offset = 3;
    }

    // Try multiple bit assignments for frame control flags
    const bitSets = [
      // (hasCapability, hasMAC, hasEvent)
      (0x01, 0x02, 0x10), // Standard MiBeacon v2
      (0x0001, 0x0002, 0x0020), // Bit 5 for event
      (0x0001, 0x0002, 0x0010), // Standard
      (0x4000, 0x0200, 0x1000), // High-byte bits
      (0x01, 0x02, 0x40), // Bit 6 for event
      (0x01, 0x40, 0x10), // Bit 6 for MAC
    ];

    for (final bits in bitSets) {
      final hasCap = (frameControl & bits.$1) != 0;
      final hasMac = (frameControl & bits.$2) != 0;
      final hasEvt = (frameControl & bits.$3) != 0;

      var off = offset;
      if (hasMac) off += 6;
      if (hasCap) off += 1;

      if (!hasEvt || off + 3 > data.length) continue;

      final result = _parseEvents(data, off);
      if (result != null) return result;
    }

    // Last resort: scan the entire data for event TLV patterns
    return _scanForEvents(data);
  }

  static EnvironmentalReading? _parseEvents(List<int> data, int offset) {
    double? temperature;
    double? humidity;
    int? battery;

    while (offset + 3 <= data.length) {
      final eventType = data[offset] | (data[offset + 1] << 8);
      final eventLen = data[offset + 2];
      offset += 3;

      if (offset + eventLen > data.length) break;

      switch (eventType) {
        case 0x1004:
          if (eventLen >= 2) {
            temperature = _toSigned16(data[offset], data[offset + 1]) / 100.0;
          }
          break;
        case 0x1006:
          if (eventLen >= 2) {
            humidity = ((data[offset] << 8) | data[offset + 1]) / 100.0;
          }
          break;
        case 0x100A:
          if (eventLen >= 1) {
            battery = data[offset];
          }
          break;
        case 0x100D:
          if (eventLen >= 4) {
            temperature = _toSigned16(data[offset], data[offset + 1]) / 100.0;
            humidity = ((data[offset + 2] << 8) | data[offset + 3]) / 100.0;
          }
          break;
      }

      offset += eventLen;
    }

    if (temperature == null && humidity == null && battery == null) {
      return null;
    }

    return EnvironmentalReading(
      temperatureCelsius: temperature,
      humidityPercent: humidity,
      batteryPercent: battery,
    );
  }

  static EnvironmentalReading? _scanForEvents(List<int> data) {
    double? temperature;
    double? humidity;
    int? battery;

    for (int i = 0; i + 3 <= data.length; i++) {
      final eventType = data[i] | (data[i + 1] << 8);
      if (eventType != 0x1004 &&
          eventType != 0x1006 &&
          eventType != 0x100A &&
          eventType != 0x100D) {
        continue;
      }
      final eventLen = data[i + 2];
      if (i + 3 + eventLen > data.length) continue;

      switch (eventType) {
        case 0x1004:
          if (eventLen >= 2) {
            temperature = _toSigned16(data[i + 3], data[i + 4]) / 100.0;
          }
        case 0x1006:
          if (eventLen >= 2) {
            humidity = ((data[i + 3] << 8) | data[i + 4]) / 100.0;
          }
        case 0x100A:
          if (eventLen >= 1) {
            battery = data[i + 3];
          }
        case 0x100D:
          if (eventLen >= 4) {
            temperature = _toSigned16(data[i + 3], data[i + 4]) / 100.0;
            humidity = ((data[i + 5] << 8) | data[i + 6]) / 100.0;
          }
      }
    }

    if (temperature == null && humidity == null && battery == null) {
      return null;
    }
    return EnvironmentalReading(
      temperatureCelsius: temperature,
      humidityPercent: humidity,
      batteryPercent: battery,
    );
  }

  static int _toSigned16(int low, int high) {
    final value = (high << 8) | low;
    return value > 32767 ? value - 65536 : value;
  }
}
