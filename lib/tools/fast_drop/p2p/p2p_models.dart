/// Transport used to move file bytes between peers.
enum P2pTransportKind { lan, ble }

/// Discovery channel through which a peer was found.
enum P2pPeerTransport { lan, ble }

/// High level state of the nearby-transfer flow.
enum P2pStatus {
  idle,
  advertising,
  scanning,
  handshaking,
  transferring,
  completed,
  failed,
  cancelled,
}

/// A device discovered via BLE advertising the Fast Drop nearby-share
/// service UUID.
class P2pPeer {
  final String id;
  final String name;
  final int rssi;
  final P2pPeerTransport transport;
  final String? lanAddress;

  const P2pPeer({
    required this.id,
    required this.name,
    required this.transport,
    this.rssi = 0,
    this.lanAddress,
  });

  String get bleDeviceId => id;

  P2pPeer copyWith({String? name, int? rssi, String? lanAddress}) => P2pPeer(
    id: id,
    name: name ?? this.name,
    rssi: rssi ?? this.rssi,
    transport: transport,
    lanAddress: lanAddress ?? this.lanAddress,
  );
}

/// Metadata describing a single file offered in a transfer session.
class P2pFileManifest {
  final String name;
  final int size;
  final String mimeType;

  const P2pFileManifest({
    required this.name,
    required this.size,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'size': size,
    'mimeType': mimeType,
  };

  factory P2pFileManifest.fromJson(Map<String, dynamic> json) =>
      P2pFileManifest(
        name: json['name'] as String,
        size: json['size'] as int,
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      );
}

/// A completed or in-flight received file, surfaced in the Nearby list.
class P2pReceivedFile {
  final String id;
  final String filename;
  final int size;
  final String mimeType;
  final String tempFileName;
  final String tempFileBaseName;
  final int receivedAt;

  const P2pReceivedFile({
    required this.id,
    required this.filename,
    required this.size,
    required this.mimeType,
    required this.tempFileName,
    required this.tempFileBaseName,
    required this.receivedAt,
  });
}
