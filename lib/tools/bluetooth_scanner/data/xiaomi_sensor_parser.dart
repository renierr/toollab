import 'environmental_reading.dart';

class XiaomiSensorParser {
  // Known Xiaomi sensor product IDs
  static const int productMjhtV1 = 0x0347;

  static bool _isXiaomiSensor(int productId) {
    return productId == productMjhtV1;
  }

  static EnvironmentalReading? parseServiceData(
    Map<String, List<int>> serviceData,
  ) {
    List<int>? data;
    for (final entry in serviceData.entries) {
      final uuid = entry.key.toLowerCase().replaceAll('-', '');
      if (uuid.contains('fe95')) {
        data = entry.value;
        break;
      }
    }
    if (data == null || data.length < 5) return null;

    return _parseXiaomiData(data);
  }

  static EnvironmentalReading? _parseXiaomiData(List<int> data) {
    final frameControl = (data[0] << 8) | data[1];
    final hasCapability = (frameControl & 0x01) != 0;
    final hasMac = (frameControl & 0x02) != 0;
    final hasEvent = (frameControl & 0x10) != 0;

    final productId = data[2] | (data[3] << 8);
    if (!_isXiaomiSensor(productId)) return null;

    int offset = 4;
    if (hasMac) offset += 6;
    if (hasCapability) offset += 1;

    if (!hasEvent || offset + 3 > data.length) return null;

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

  static int _toSigned16(int low, int high) {
    final value = (high << 8) | low;
    return value > 32767 ? value - 65536 : value;
  }
}
