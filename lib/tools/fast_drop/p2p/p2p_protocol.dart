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
  /// sender), carries the number of chunks received so far as a varint-ish
  /// little-endian uint32.
  static const String ackCharUuid = '7a51c1b3-6e9e-4e6a-8f9a-9e2b5b2b6a11';

  /// TCP port the LAN transfer server listens on.
  static const int lanPort = 53211;

  /// Size of each BLE fallback chunk payload, comfortably under common
  /// negotiated MTUs (247 requested, 23 default) so it works even if MTU
  /// negotiation fails.
  static const int bleChunkSize = 180;

  /// Conservative default GATT write/notify payload size assumed before any
  /// MTU negotiation has taken place (default ATT MTU is 23 bytes, minus a
  /// 3-byte ATT header). Writes/notifications larger than the negotiated
  /// (or this default) size are split using [chunkWithLengthPrefix] so they
  /// survive even on stacks that don't support automatic GATT long writes.
  static const int defaultSafeChunkSize = 20;

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
    final safeChunkSize = chunkSize < 8 ? 8 : chunkSize;
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

  const P2pHandshakeResponse({
    required this.accepted,
    required this.receiverName,
    this.candidateIps = const [],
    this.lanPort = P2pProtocol.lanPort,
    this.transferToken,
  });

  Map<String, dynamic> toJson() => {
    'type': 'response',
    'accepted': accepted,
    'receiverName': receiverName,
    'candidateIps': candidateIps,
    'lanPort': lanPort,
    'transferToken': transferToken,
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
      );
}
