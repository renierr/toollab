import 'dart:typed_data';

/// Pure encode/decode for the treadmill BLE protocols (FTMS, PitPat, RSC,
/// Heart Rate). No app state — every function maps bytes to/from plain data so
/// the parsing can be reasoned about and tested in isolation.

// PitPat running-state bits (value[26] & 24).
const int pitpatStateStarting = 24;
const int pitpatStateRunning = 8;
const int pitpatStatePaused = 16;

/// Heartbeat the PitPat treadmill needs at ~2 Hz to keep streaming telemetry.
final Uint8List pitpatHeartbeatPacket = Uint8List.fromList([
  0x6a,
  0x05,
  0xfd,
  0xf8,
  0x43,
]);

class PitPatFrame {
  final double speed; // km/h
  final double distance; // km
  final int calories;
  final int steps;
  final int durationMs;
  final int runningStateBits;

  const PitPatFrame({
    required this.speed,
    required this.distance,
    required this.calories,
    required this.steps,
    required this.durationMs,
    required this.runningStateBits,
  });
}

/// Decodes a PitPat telemetry notification. Returns null if too short.
PitPatFrame? decodePitPatTelemetry(Uint8List value) {
  if (value.length < 31) return null;
  final int rawSpeed = (value[3] << 8) | value[4];
  final int rawDist =
      (value[7] << 24) | (value[8] << 16) | (value[9] << 8) | value[10];
  final int stepsVal =
      (value[14] << 24) | (value[15] << 16) | (value[16] << 8) | value[17];
  final int cals = (value[18] << 8) | value[19];
  final int durationMs =
      (value[20] << 24) | (value[21] << 16) | (value[22] << 8) | value[23];

  return PitPatFrame(
    speed: rawSpeed / 1000.0,
    distance: rawDist / 1000.0,
    calories: cals,
    steps: stepsVal,
    durationMs: durationMs,
    runningStateBits: value[26] & 24,
  );
}

/// Builds a PitPat control packet for START / PAUSE / STOP / SPEED.
Uint8List makePitPatPacket(String action, double speedKph) {
  final arr = Uint8List(23);
  arr[0] = 0x6a;
  arr[1] = 0x17;

  final int speedUnit = (speedKph * 1000).round();
  arr[6] = (speedUnit >> 8) & 0xff;
  arr[7] = speedUnit & 0xff;

  arr[8] = action == 'SPEED' ? 0x05 : 0x01;
  arr[9] = 0x00;
  arr[10] = 80;
  arr[11] = 0x00;

  int cmd = action == 'PAUSE' ? 2 : (action == 'STOP' ? 0 : 4);
  arr[12] = cmd & 0xf7;

  const int userId = 58965456623;
  for (int i = 0; i < 8; ++i) {
    arr[13 + i] = (userId >> (56 - i * 8)) & 0xff;
  }

  int checksum = 0;
  for (int i = 1; i <= 20; ++i) {
    checksum ^= arr[i];
  }
  arr[21] = checksum;
  arr[22] = 0x43;

  return arr;
}

class FtmsTelemetry {
  final double speed; // km/h
  final double? distance; // km
  final double? incline; // %
  final int? calories;
  final int? heartRate; // bpm
  final int? elapsedTimeSec;

  const FtmsTelemetry({
    required this.speed,
    this.distance,
    this.incline,
    this.calories,
    this.heartRate,
    this.elapsedTimeSec,
  });
}

/// Decodes an FTMS Treadmill Data notification (flags-driven field layout).
/// Returns null if too short. Only fields whose presence flag is set (and that
/// fit in the buffer) are non-null.
FtmsTelemetry? decodeFtmsTelemetry(Uint8List value) {
  if (value.length < 4) return null;
  final flags = ByteData.sublistView(value).getUint16(0, Endian.little);
  int offset = 2;

  final double speed =
      ByteData.sublistView(value).getUint16(offset, Endian.little) / 100.0;
  offset += 2;

  double? distance;
  double? incline;
  int? calories;
  int? heartRate;
  int? elapsedTimeSec;

  if ((flags & (1 << 1)) != 0 && value.length >= offset + 2) {
    offset += 2;
  }

  if ((flags & (1 << 2)) != 0 && value.length >= offset + 3) {
    final d1 = value[offset];
    final d2 = value[offset + 1];
    final d3 = value[offset + 2];
    distance = (d1 | (d2 << 8) | (d3 << 16)) / 1000.0;
    offset += 3;
  }

  if ((flags & (1 << 3)) != 0 && value.length >= offset + 2) {
    incline =
        ByteData.sublistView(value).getInt16(offset, Endian.little) / 10.0;
    offset += 4; // Skip inclination + suspension
  }

  if ((flags & (1 << 4)) != 0 && value.length >= offset + 4) {
    offset += 4;
  }

  if ((flags & (1 << 5)) != 0 && value.length >= offset + 1) {
    offset += 1;
  }

  if ((flags & (1 << 6)) != 0 && value.length >= offset + 1) {
    offset += 1;
  }

  if ((flags & (1 << 7)) != 0 && value.length >= offset + 5) {
    calories = ByteData.sublistView(value).getUint16(offset, Endian.little);
    offset += 5;
  }

  if ((flags & (1 << 8)) != 0 && value.length >= offset + 1) {
    heartRate = value[offset];
    offset += 1;
  }

  if ((flags & (1 << 9)) != 0 && value.length >= offset + 1) {
    offset += 1;
  }

  if ((flags & (1 << 10)) != 0 && value.length >= offset + 2) {
    elapsedTimeSec = ByteData.sublistView(
      value,
    ).getUint16(offset, Endian.little);
  }

  return FtmsTelemetry(
    speed: speed,
    distance: distance,
    incline: incline,
    calories: calories,
    heartRate: heartRate,
    elapsedTimeSec: elapsedTimeSec,
  );
}

/// FTMS speed / incline control capability from the Machine Feature read.
class FtmsControlSupport {
  final bool speed;
  final bool incline;

  const FtmsControlSupport({required this.speed, required this.incline});
}

/// Decodes the FTMS feature characteristic. Returns null if too short.
FtmsControlSupport? decodeFtmsFeatures(Uint8List value) {
  if (value.length < 8) return null;
  final data = ByteData.sublistView(value);
  final machineFeatures = data.getUint32(0, Endian.little);
  if ((machineFeatures & (1 << 14)) != 0) {
    final targetFeatures = data.getUint32(4, Endian.little);
    return FtmsControlSupport(
      speed: (targetFeatures & (1 << 0)) != 0,
      incline: (targetFeatures & (1 << 1)) != 0,
    );
  }
  return const FtmsControlSupport(speed: false, incline: false);
}

/// Decodes total step count from a Running Speed & Cadence notification.
/// Returns null if no step field is present.
int? decodeRscSteps(Uint8List value) {
  if (value.length < 4) return null;
  try {
    final flags = value[0];
    int offset = 3;
    offset += 1; // skip cadence

    if ((flags & 0x01) != 0 && value.length >= offset + 2) {
      offset += 2;
    }
    if ((flags & 0x02) != 0 && value.length >= offset + 4) {
      offset += 4;
    }

    final remaining = value.length - offset;
    if (remaining >= 4) {
      return ByteData.sublistView(value).getUint32(offset, Endian.little);
    } else if (remaining >= 2) {
      return ByteData.sublistView(value).getUint16(offset, Endian.little);
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Decodes heart rate (bpm) from a Heart Rate Measurement notification.
/// Returns 0 when unavailable.
int decodeHeartRate(Uint8List value) {
  if (value.isEmpty) return 0;
  final flags = value[0];
  final is16bit = (flags & 0x01) == 1;
  if (is16bit && value.length >= 3) {
    return ByteData.sublistView(value).getUint16(1, Endian.little);
  } else if (value.length >= 2) {
    return value[1];
  }
  return 0;
}
