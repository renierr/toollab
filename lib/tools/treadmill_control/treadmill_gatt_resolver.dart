import 'package:universal_ble/universal_ble.dart';
import 'treadmill_models.dart';

/// Resolved treadmill service/characteristic UUIDs from a discovery result.
/// Any field may be null when the device did not expose it.
class TreadmillGattProfile {
  final bool hasPitPat;
  final bool hasFtms;
  final String? service;
  final String? dataChar;
  final String? controlPointChar;
  final String? featureChar;
  final String? writeChar;

  const TreadmillGattProfile({
    required this.hasPitPat,
    required this.hasFtms,
    this.service,
    this.dataChar,
    this.controlPointChar,
    this.featureChar,
    this.writeChar,
  });

  /// PitPat only when it advertises PitPat and not FTMS; otherwise FTMS.
  TreadmillType get type =>
      hasPitPat && !hasFtms ? TreadmillType.pitpat : TreadmillType.ftms;
}

/// Inspects discovered services for PitPat (fba0) and FTMS (1826) profiles.
TreadmillGattProfile resolveTreadmillGatt(List<BleService> services) {
  bool hasPitPat = false;
  bool hasFtms = false;
  String? service;
  String? dataChar;
  String? controlPointChar;
  String? featureChar;
  String? writeChar;

  for (final s in services) {
    final uuid = s.uuid.toLowerCase();
    if (uuid.contains('fba0')) {
      hasPitPat = true;
      service = s.uuid;
      for (final c in s.characteristics) {
        final cUuid = c.uuid.toLowerCase();
        if (cUuid.contains('fba2')) dataChar = c.uuid;
        if (cUuid.contains('fba1')) writeChar = c.uuid;
      }
    }
    if (uuid.contains('1826')) {
      hasFtms = true;
      service = s.uuid;
      for (final c in s.characteristics) {
        final cUuid = c.uuid.toLowerCase();
        if (cUuid.contains('2acd')) dataChar = c.uuid;
        if (cUuid.contains('2ad9')) controlPointChar = c.uuid;
        if (cUuid.contains('2acc')) featureChar = c.uuid;
      }
    }
  }

  return TreadmillGattProfile(
    hasPitPat: hasPitPat,
    hasFtms: hasFtms,
    service: service,
    dataChar: dataChar,
    controlPointChar: controlPointChar,
    featureChar: featureChar,
    writeChar: writeChar,
  );
}

/// Resolved heart-rate and battery service/characteristic UUIDs.
class HrmGattProfile {
  final String? hrService;
  final String? hrChar;
  final String? batteryService;
  final String? batteryChar;

  const HrmGattProfile({
    this.hrService,
    this.hrChar,
    this.batteryService,
    this.batteryChar,
  });
}

/// Inspects discovered services for Heart Rate (180d) and Battery (180f).
HrmGattProfile resolveHrmGatt(List<BleService> services) {
  String? hrService;
  String? hrChar;
  String? batteryService;
  String? batteryChar;

  for (final s in services) {
    final uuid = s.uuid.toLowerCase();
    if (uuid.contains('180d')) {
      hrService = s.uuid;
      for (final c in s.characteristics) {
        if (c.uuid.toLowerCase().contains('2a37')) hrChar = c.uuid;
      }
    }
    if (uuid.contains('180f')) {
      batteryService = s.uuid;
      for (final c in s.characteristics) {
        if (c.uuid.toLowerCase().contains('2a19')) batteryChar = c.uuid;
      }
    }
  }

  return HrmGattProfile(
    hrService: hrService,
    hrChar: hrChar,
    batteryService: batteryService,
    batteryChar: batteryChar,
  );
}
