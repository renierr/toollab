/// Transport used to move file bytes between peers.
enum P2pTransportKind { lan, ble }

/// High level state of the nearby-transfer flow.
enum P2pStatus {
  idle,
  advertising,
  scanning,
  handshaking,
  connectingLan,
  transferring,
  completed,
  failed,
  cancelled,
}

/// A device discovered via BLE advertising the Fast Drop nearby-share
/// service UUID.
class P2pPeer {
  final String bleDeviceId;
  final String name;
  final int rssi;

  const P2pPeer({required this.bleDeviceId, required this.name, this.rssi = 0});

  P2pPeer copyWith({String? name, int? rssi}) => P2pPeer(
    bleDeviceId: bleDeviceId,
    name: name ?? this.name,
    rssi: rssi ?? this.rssi,
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
  final int receivedAt;

  const P2pReceivedFile({
    required this.id,
    required this.filename,
    required this.size,
    required this.mimeType,
    required this.tempFileName,
    required this.receivedAt,
  });
}
