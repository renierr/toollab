/// Wire protocol of the Renpho MorphoScan Nova (RT-MSC04 / R-AMSC04).
///
/// Frame layout, verified against Android HCI captures and the matching cloud
/// export:
///
///     55 AA <type> <len:2> <seq> <flags> [<age:4> for 0x26 only] <weight:4>
///           <count> <count x impedance:2> <calcFlag> <bodyfat:2> <bmi:2>
///           <muscle:2> <visfat:2> <checksum>
///
/// Every multibyte field is big-endian. `weight` is a uint32 whose two leading
/// bytes are zero at human weights, and `bodyfat` plus the trunk impedances are
/// uint16 that overflow a single-byte read above 25.5.
library;

import 'dart:typed_data';

/// The ten segment impedances, in the order the scale sends them.
const renphoImpedanceFields = [
  'z20Body',
  'z20HandL',
  'z20HandR',
  'z20FootL',
  'z20FootR',
  'z100Body',
  'z100HandL',
  'z100HandR',
  'z100FootL',
  'z100FootR',
];

class RenphoScaleUuids {
  RenphoScaleUuids._();

  static const controlService = '00001a10-0000-1000-8000-00805f9b34fb';
  static const controlWrite = '00002a11-0000-1000-8000-00805f9b34fb';
  static const controlNotify = '00002a10-0000-1000-8000-00805f9b34fb';
  static const controlIndicate = '00002a12-0000-1000-8000-00805f9b34fb';

  /// Multi-part body-composition results arrive here, not on the control
  /// service. Missing this subscription is why a scan can reach "ready" and
  /// then never produce a result.
  static const resultTransport = '00000003-0000-1000-8000-00805f9b34fb';
}

/// A decoded body-composition record.
class RenphoScaleResult {
  final int type;
  final int sequence;
  final double weightKg;

  /// Seconds between the measurement and its transfer, for stored (0x26)
  /// records. Live results carry no age.
  final int? recordAgeSeconds;

  /// False when the scale sends impedances only and leaves the body
  /// composition zeroed, which is not a measurement and must not be stored.
  final bool hasBodyComposition;
  final double bodyFatPercent;
  final double bmi;
  final double musclePercent;
  final int visceralFat;
  final Map<String, double> impedance;
  final String packetHex;

  const RenphoScaleResult({
    required this.type,
    required this.sequence,
    required this.weightKg,
    required this.recordAgeSeconds,
    required this.hasBodyComposition,
    required this.bodyFatPercent,
    required this.bmi,
    required this.musclePercent,
    required this.visceralFat,
    required this.impedance,
    required this.packetHex,
  });

  bool get isStored => type == 0x26;

  /// When the reading was taken, derived from [recordAgeSeconds] for stored
  /// records and from the arrival time for live ones.
  DateTime measuredAt(DateTime receivedAt) => recordAgeSeconds == null
      ? receivedAt
      : receivedAt.subtract(Duration(seconds: recordAgeSeconds!));
}

/// Decodes a reassembled 0x24 / 0x25 / 0x26 record, or null when the packet is
/// not one, is truncated, or carries no body composition.
RenphoScaleResult? decodeRenphoResult(List<int> packet) {
  if (packet.length < 12 || packet[0] != 0x55 || packet[1] != 0xAA) return null;
  final type = packet[2];
  if (type != 0x24 && type != 0x25 && type != 0x26) return null;

  var offset = 7;
  int? age;
  if (type == 0x26) {
    age = _u32(packet, 7);
    offset = 11;
  }
  if (packet.length < offset + 5) return null;
  final weightKg = _u32(packet, offset) / 100;

  final count = packet[offset + 4];
  final impedanceAt = offset + 5;
  final calcAt = impedanceAt + 2 * count;
  // 0x24 carries the weight only; the byte read as `count` there is its
  // checksum. An unexpected count is left undecoded rather than guessed at.
  if (count != renphoImpedanceFields.length || packet.length < calcAt + 9) {
    return null;
  }

  final impedance = <String, double>{
    for (var index = 0; index < renphoImpedanceFields.length; index++)
      renphoImpedanceFields[index]: _u16(packet, impedanceAt + 2 * index) / 10,
  };

  final hasComposition = packet[calcAt] != 0;
  return RenphoScaleResult(
    type: type,
    sequence: packet[5],
    weightKg: weightKg,
    recordAgeSeconds: age,
    hasBodyComposition: hasComposition,
    bodyFatPercent: hasComposition ? _u16(packet, calcAt + 1) / 10 : 0,
    bmi: hasComposition ? _u16(packet, calcAt + 3) / 10 : 0,
    musclePercent: hasComposition ? _u16(packet, calcAt + 5) / 10 : 0,
    visceralFat: hasComposition ? _u16(packet, calcAt + 7) : 0,
    impedance: impedance,
    packetHex: renphoHex(packet),
  );
}

/// Live weight from a 0x21 telemetry frame, in kilograms.
double? decodeRenphoLiveWeight(List<int> packet) {
  if (packet.length < 10 || packet[0] != 0x55 || packet[1] != 0xAA) return null;
  if (packet[2] != 0x21) return null;
  return _u16(packet, 8) / 100;
}

/// Reassembles the AD / AE / AF ATT fragments that carry extended results.
///
/// AD opens a sequence, AE continues it, and AF with a zero remaining-count
/// closes it. Feed every fragment in; a completed packet comes back once.
class RenphoFragmentAssembler {
  final _chunks = <int, List<int>>{};

  static bool isFragment(List<int> frame) =>
      frame.length >= 4 &&
      (frame[0] == 0xAD || frame[0] == 0xAE || frame[0] == 0xAF);

  List<int>? add(List<int> fragment) {
    if (!isFragment(fragment)) return null;
    final marker = fragment[0];
    final sequence = fragment[1];
    final remaining = fragment[2];
    if (marker == 0xAD) _chunks[sequence] = [];
    final chunks = _chunks[sequence];
    if (chunks == null) return null;
    chunks.addAll(fragment.sublist(3));
    if (marker != 0xAF || remaining != 0) return null;
    _chunks.remove(sequence);
    return chunks;
  }

  void clear() => _chunks.clear();
}

/// Packets the app sends. The profile bytes inside the B2 handshake were
/// captured from the official app and are not decoded.
class RenphoScaleCommands {
  RenphoScaleCommands._();

  /// The scale expects the last weight the app knows about, and the official
  /// app re-sends this packet after every result to close the session.
  static Uint8List handshake({int sequence = 0, double? lastWeightKg}) {
    final grams = ((lastWeightKg ?? 65.75) * 100).round().clamp(0, 0xFFFF);
    return _withChecksum([
      0x55, 0xAA, 0xB2, 0x00, 0x09, sequence & 0xFF, 0x01, 0x06, //
      0xC2, (grams >> 8) & 0xFF, grams & 0xFF, 0xB2, 0x01, 0x02,
    ]);
  }

  static Uint8List setClock(DateTime now, {int sequence = 0x01}) {
    final seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final offset = now.timeZoneOffset.inMinutes;
    return _withChecksum([
      0x55, 0xAA, 0xB3, 0x00, 0x0B, sequence & 0xFF, 0x07, 0x01, 0x01, //
      (seconds >> 24) & 0xFF, (seconds >> 16) & 0xFF,
      (seconds >> 8) & 0xFF, seconds & 0xFF,
      (offset >> 8) & 0xFF, offset & 0xFF, 0x00,
    ]);
  }

  static Uint8List requestStoredRecords({int sequence = 0x02}) =>
      _withChecksum([
        0x55, 0xAA, 0xB8, 0x00, 0x0C, sequence & 0xFF, 0x01, 0x00, 0x00, //
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);

  static Uint8List selectUser(String name, {int sequence = 0x03}) {
    final encoded = _asciiName(name);
    return _withChecksum([
      0x55, 0xAA, 0xB7, 0x00, 6 + encoded.length, sequence & 0xFF, 0x01, //
      0x00, 0x01, 0x00, encoded.length, ...encoded,
    ]);
  }

  static Uint8List acknowledge(int sequence) =>
      _withChecksum([0x55, 0xAA, 0xB6, 0x00, 0x02, sequence, 0x01]);

  /// The capture only ever shows single-byte characters here, so anything
  /// outside printable ASCII is replaced rather than sent as multibyte UTF-8.
  static List<int> _asciiName(String name) {
    final trimmed = name.trim().isEmpty ? 'User' : name.trim();
    return [
      for (final unit in trimmed.codeUnits.take(16))
        unit >= 0x20 && unit <= 0x7E ? unit : 0x3F,
    ];
  }
}

/// The frame type the scale answers a setup command with: the command type
/// minus 0x90, so 0xB2 is acknowledged by 0x22. Captures disagree about the
/// pairing across firmware revisions, so callers treat this as a hint.
int renphoAckFor(int commandType) => (commandType - 0x90) & 0xFF;

/// 0x20 is a free-running state broadcast, not an acknowledgement — the scale
/// emits it on connect and again when the impedance phase starts.
bool renphoIsStateBroadcast(int type) => type == 0x20;

/// The state byte inside a 0x20 broadcast, or null when the frame is too short.
int? renphoBroadcastState(List<int> packet) =>
    packet.length > 6 && packet[2] == 0x20 ? packet[6] : null;

Uint8List _withChecksum(List<int> packet) => Uint8List.fromList([
  ...packet,
  packet.fold<int>(0, (sum, byte) => (sum + byte) & 0xFF),
]);

bool renphoChecksumValid(List<int> packet) =>
    packet.length > 1 &&
    packet
                .sublist(0, packet.length - 1)
                .fold<int>(0, (sum, byte) => sum + byte) &
            0xFF ==
        packet.last;

String renphoHex(List<int> bytes) => bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');

int _u16(List<int> bytes, int offset) =>
    (bytes[offset] << 8) | bytes[offset + 1];

int _u32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
