import 'dart:convert';
import 'dart:typed_data';

/// Wire protocol constants and message (de)serialization for Fast Drop's
/// nearby (BLE + LAN) peer-to-peer transfer feature.
///
/// Handshake payloads are small JSON blobs exchanged over a BLE GATT
/// characteristic. The actual file bytes never go through the handshake
/// characteristic — they go over a direct TCP socket when both peers share
/// a network, or over the chunked BLE data characteristic as a fallback.
class P2pProtocol {
  P2pProtocol._();

  /// Custom 128-bit service UUID identifying a Fast Drop nearby-share
  /// advertiser. Random UUID picked for this app, not a standard GATT
  /// service — used purely as a filter so unrelated BLE devices are
  /// ignored during scanning.
  static const String serviceUuid = '7a51c1b0-6e9e-4e6a-8f9a-9e2b5b2b6a11';

  /// Peer -> Peer handshake request/response payload (JSON).
  static const String handshakeCharUuid =
      '7a51c1b1-6e9e-4e6a-8f9a-9e2b5b2b6a11';

  /// Chunked file data fallback channel, used only when no direct LAN
  /// socket connection could be established.
  static const String dataCharUuid = '7a51c1b2-6e9e-4e6a-8f9a-9e2b5b2b6a11';

  /// Ack/flow-control channel for the BLE fallback transfer (receiver ->
  /// sender), carries the number of bytes written to disk so far as a
  /// little-endian uint32.
  static const String ackCharUuid = '7a51c1b3-6e9e-4e6a-8f9a-9e2b5b2b6a11';

  /// TCP port the LAN transfer server listens on.
  static const int lanDiscoveryPort = 53210;

  /// TCP port for direct LAN handshakes and file streams.
  static const int lanPort = 53212;

  /// Legacy raw TCP fallback negotiated through a BLE handshake. Kept
  /// separate from [lanPort], whose connections always begin with JSON.
  static const int bleLanFallbackPort = 53211;

  /// Conservative default GATT write/notify payload size assumed before any
  /// MTU negotiation has taken place (default ATT MTU is 23 bytes, minus a
  /// 3-byte ATT header). Writes/notifications larger than the negotiated
  /// (or this default) size are split using [chunkWithLengthPrefix] so they
  /// survive even on stacks that don't support automatic GATT long writes.
  static const int defaultSafeChunkSize = 20;

  /// Largest payload a single GATT write or notification may carry: the ATT
  /// maximum attribute length. A peer that negotiates a bigger MTU (Windows
  /// asks for 517) must not be turned into a bigger chunk — Android's
  /// `writeCharacteristic` rejects a longer value by throwing, which only
  /// surfaces in Dart as a platform-channel failure.
  static const int maxGattPayloadSize = 512;

  /// Clamps a payload size derived from a negotiated MTU into the range a
  /// single write/notification can actually carry.
  static int safePayloadSize(int size) {
    if (size < 8) return defaultSafeChunkSize;
    return size > maxGattPayloadSize ? maxGattPayloadSize : size;
  }

  /// How many chunks the BLE sender may run ahead of the last acked byte
  /// count before it waits for the receiver to catch up.
  static const int bleAckWindowChunks = 8;

  /// No progress on the BLE fallback for this long counts as a dead
  /// transfer on either side, rather than hanging forever.
  static const Duration bleStallTimeout = Duration(seconds: 20);

  /// How often the receiver repeats its latest cumulative ack. GATT
  /// notifications are lossy (Android silently drops one while another is
  /// still in flight), and acks are otherwise only produced by incoming
  /// chunks — so a single lost ack inside the final send window would leave
  /// the sender waiting for a count that is never sent again.
  static const Duration bleAckResendInterval = Duration(seconds: 1);

  /// How often the closing ack is repeated once the receiver has the whole
  /// file. No further chunk arrives to trigger one, so it has to keep
  /// answering for as long as the sender may still be asking — long enough
  /// to cover [bleFinalAckGrace] plus every [bleTailResendAttempts] round.
  static const int bleClosingAckRepeats = 14;

  /// Gap between the repeated closing acks.
  static const Duration bleClosingAckInterval = Duration(seconds: 1);

  /// How long the sender waits for the closing ack before it treats the
  /// difference as writes the receiver never saw.
  static const Duration bleFinalAckGrace = Duration(seconds: 3);

  /// How recently the sender must have heard from the receiver before it
  /// dares re-send a gap. Resending against a stale count would append bytes
  /// the receiver already holds, so a quiet peer is failed instead.
  static const Duration bleAckFreshness = Duration(milliseconds: 2500);

  /// How often the sender re-sends the unacked tail before giving up.
  static const int bleTailResendAttempts = 3;

  /// How long to try connecting to each candidate LAN IP.
  static const Duration lanConnectAttemptTimeout = Duration(seconds: 2);

  /// Overall budget before giving up on LAN and falling back to BLE.
  static const Duration lanConnectOverallTimeout = Duration(seconds: 5);

  /// Splits [payload] into a sequence of GATT write-sized chunks, prefixing
  /// the very first chunk with a 4-byte big-endian total length so the
  /// receiver knows when the logical message is complete. Needed because a
  /// single handshake JSON message is almost always bigger than the default
  /// (and sometimes even the negotiated) ATT payload size, and not every
  /// platform performs an automatic GATT "long write" for oversized writes.
  static List<Uint8List> chunkWithLengthPrefix(
    Uint8List payload, {
    required int chunkSize,
  }) {
    final safeChunkSize = safePayloadSize(chunkSize);
    final header = ByteData(4)..setUint32(0, payload.length, Endian.big);
    final withHeader = Uint8List(4 + payload.length)
      ..setRange(0, 4, header.buffer.asUint8List())
      ..setRange(4, 4 + payload.length, payload);

    final chunks = <Uint8List>[];
    for (var offset = 0; offset < withHeader.length; offset += safeChunkSize) {
      final end = (offset + safeChunkSize < withHeader.length)
          ? offset + safeChunkSize
          : withHeader.length;
      chunks.add(withHeader.sublist(offset, end));
    }
    return chunks;
  }
}

/// Reassembles a length-prefixed chunked message (see
/// [P2pProtocol.chunkWithLengthPrefix]) as chunks arrive, one accumulator
/// per remote device id.
class P2pChunkReassembler {
  final Map<String, _PendingMessage> _pending = {};

  /// Feeds a raw chunk from [deviceId]. Returns the fully reassembled
  /// message once the declared length has been reached, otherwise null.
  Uint8List? feed(String deviceId, Uint8List chunk) {
    var pending = _pending[deviceId];
    var data = chunk;

    if (pending == null) {
      if (chunk.length < 4) return null;
      final totalLength = ByteData.sublistView(
        chunk,
        0,
        4,
      ).getUint32(0, Endian.big);
      pending = _PendingMessage(totalLength);
      _pending[deviceId] = pending;
      data = chunk.sublist(4);
    }

    pending.buffer.addAll(data);
    if (pending.buffer.length >= pending.totalLength) {
      final complete = Uint8List.fromList(
        pending.buffer.sublist(0, pending.totalLength),
      );
      _pending.remove(deviceId);
      return complete;
    }
    return null;
  }

  void reset(String deviceId) => _pending.remove(deviceId);

  void clear() => _pending.clear();
}

class _PendingMessage {
  final int totalLength;
  final List<int> buffer = [];
  _PendingMessage(this.totalLength);
}

/// Handshake message sent by the initiating (sending) device once BLE
/// central-connected to the advertising peer.
class P2pHandshakeRequest {
  final String senderName;
  final List<String> candidateIps;
  final int lanPort;
  final String fileName;
  final int fileSize;
  final String mimeType;

  const P2pHandshakeRequest({
    required this.senderName,
    required this.candidateIps,
    required this.lanPort,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
    'type': 'request',
    'senderName': senderName,
    'candidateIps': candidateIps,
    'lanPort': lanPort,
    'fileName': fileName,
    'fileSize': fileSize,
    'mimeType': mimeType,
  };

  String encode() => jsonEncode(toJson());

  factory P2pHandshakeRequest.fromJson(Map<String, dynamic> json) =>
      P2pHandshakeRequest(
        senderName: json['senderName'] as String? ?? 'Unknown device',
        candidateIps: (json['candidateIps'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        lanPort: json['lanPort'] as int? ?? P2pProtocol.lanPort,
        fileName: json['fileName'] as String? ?? 'file',
        fileSize: json['fileSize'] as int? ?? 0,
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      );
}

/// Handshake response sent by the receiving (advertising) device.
class P2pHandshakeResponse {
  final bool accepted;
  final String receiverName;
  final List<String> candidateIps;
  final int lanPort;
  final String? transferToken;

  /// Largest GATT payload the receiver's own stack reports for this link,
  /// or null when it cannot tell. The two platforms do not always agree on
  /// the negotiated MTU, so the sender writes at the smaller of the two.
  final int? maxPayload;

  const P2pHandshakeResponse({
    required this.accepted,
    required this.receiverName,
    this.candidateIps = const [],
    this.lanPort = P2pProtocol.lanPort,
    this.transferToken,
    this.maxPayload,
  });

  Map<String, dynamic> toJson() => {
    'type': 'response',
    'accepted': accepted,
    'receiverName': receiverName,
    'candidateIps': candidateIps,
    'lanPort': lanPort,
    'transferToken': transferToken,
    'maxPayload': maxPayload,
  };

  String encode() => jsonEncode(toJson());

  factory P2pHandshakeResponse.fromJson(Map<String, dynamic> json) =>
      P2pHandshakeResponse(
        accepted: json['accepted'] as bool? ?? false,
        receiverName: json['receiverName'] as String? ?? 'Unknown device',
        candidateIps: (json['candidateIps'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        lanPort: json['lanPort'] as int? ?? P2pProtocol.lanPort,
        transferToken: json['transferToken'] as String?,
        maxPayload: json['maxPayload'] as int?,
      );
}
