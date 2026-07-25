import 'dart:convert';

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

  /// How long to try connecting to each candidate LAN IP.
  static const Duration lanConnectAttemptTimeout = Duration(seconds: 2);

  /// Overall budget before giving up on LAN and falling back to BLE.
  static const Duration lanConnectOverallTimeout = Duration(seconds: 5);
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
