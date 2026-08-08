import 'dart:async';
import 'package:tool_lab/helpers/debug_log.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'p2p/p2p_discovery_service.dart';
import 'p2p/p2p_lan_service.dart';
import 'p2p/p2p_models.dart';
import 'p2p/p2p_protocol.dart';
import 'p2p/p2p_transfer_service.dart';

/// Which side of the nearby-transfer flow the user is currently on.
enum P2pRole { none, sending, receiving }

/// ChangeNotifier backing the Fast Drop "Nearby" (P2P) tab. Owns BLE
/// discovery/handshake and the LAN/BLE transfer, exposing peers, incoming
/// requests and transfer progress to the UI.
class FastDropP2pState extends ChangeNotifier {
  final P2pDiscoveryService _discovery = P2pDiscoveryService();
  final P2pLanService _lan = P2pLanService();
  final P2pTransferService _transfer = P2pTransferService();

  StreamSubscription<List<P2pPeer>>? _peersSub;
  StreamSubscription<(String, P2pHandshakeRequest)>? _incomingSub;
  StreamSubscription<String>? _advertisingErrorSub;
  StreamSubscription<List<P2pPeer>>? _lanPeersSub;
  StreamSubscription<P2pLanIncomingRequest>? _lanIncomingSub;

  P2pRole _role = P2pRole.none;
  List<P2pPeer> _peers = [];
  P2pStatus _status = P2pStatus.idle;
  P2pTransportKind? _activeTransport;
  (int current, int total)? _progress;
  String? _error;
  bool _cancelRequested = false;
  int _lastProgressNotifyMs = 0;

  /// Pending accept/reject prompt while advertising as a receiver.
  (P2pPeer peer, P2pHandshakeRequest request)? _incomingRequest;

  final List<P2pReceivedFile> _receivedFiles = [];

  String? _pendingSendFilePath;
  String? _pendingSendFileName;
  int? _pendingSendFileSize;
  String? _pendingSendMimeType;

  P2pRole get role => _role;
  List<P2pPeer> get peers => List.unmodifiable(_peers);
  P2pStatus get status => _status;
  P2pTransportKind? get activeTransport => _activeTransport;
  (int current, int total)? get progress => _progress;
  String? get error => _error;
  (P2pPeer peer, P2pHandshakeRequest request)? get incomingRequest =>
      _incomingRequest;
  List<P2pReceivedFile> get receivedFiles => List.unmodifiable(_receivedFiles);
  bool get isBusy =>
      _status == P2pStatus.advertising ||
      _status == P2pStatus.scanning ||
      _status == P2pStatus.handshaking ||
      _status == P2pStatus.transferring;

  /// True only while an actual transfer is in flight (handshake through
  /// completion) — used to disable the receive/scan toggles without
  /// blocking the user from stopping advertising/scanning itself.
  bool get isTransferActive =>
      _status == P2pStatus.handshaking || _status == P2pStatus.transferring;

  // ---------------------------------------------------------------------
  // Receiver flow
  // ---------------------------------------------------------------------

  Future<void> startReceiving(String deviceName) async {
    if (_role == P2pRole.sending) {
      await stopScanningForPeers();
    }
    _role = P2pRole.receiving;
    _status = P2pStatus.advertising;
    _error = null;
    notifyListeners();

    try {
      await _incomingSub?.cancel();
      _incomingSub = _discovery.onIncomingRequest.listen((event) {
        _incomingRequest = (
          P2pPeer(
            id: event.$1,
            name: event.$2.senderName,
            transport: P2pPeerTransport.ble,
          ),
          event.$2,
        );
        notifyListeners();
      });
      await _lanIncomingSub?.cancel();
      _lanIncomingSub = _lan.incomingRequests.listen((event) {
        _incomingRequest = event;
        notifyListeners();
      });
      await _advertisingErrorSub?.cancel();
      _advertisingErrorSub = _discovery.onAdvertisingError.listen((message) {
        _error = message;
        _status = P2pStatus.failed;
        notifyListeners();
      });
      await _lan.startReceiving(deviceName);
      if (!Platform.isLinux) {
        try {
          await _discovery.startAdvertisingAsReceiver(deviceName);
        } catch (e) {
          errorLog('[FastDropP2p] BLE receiving unavailable: $e');
        }
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _status = P2pStatus.failed;
      notifyListeners();
    }
  }

  Future<void> stopReceiving() async {
    await _discovery.stopAdvertising();
    await _lan.stopReceiving();
    await _incomingSub?.cancel();
    _incomingSub = null;
    await _advertisingErrorSub?.cancel();
    _advertisingErrorSub = null;
    await _lanIncomingSub?.cancel();
    _lanIncomingSub = null;
    _incomingRequest = null;
    if (_role == P2pRole.receiving) {
      _role = P2pRole.none;
      _status = P2pStatus.idle;
    }
    notifyListeners();
  }

  /// Accepts an incoming send request, chooses an output file name, and
  /// runs the transfer (LAN first, BLE fallback).
  Future<void> acceptIncomingRequest(
    String outputPath, {
    required String tempFileBaseName,
  }) async {
    final incoming = _incomingRequest;
    if (incoming == null) return;
    final (peer, request) = incoming;
    _incomingRequest = null;
    _status = P2pStatus.handshaking;
    _cancelRequested = false;
    notifyListeners();

    try {
      _status = P2pStatus.transferring;
      _activeTransport = null;
      _progress = (0, request.fileSize);
      notifyListeners();

      final savedPath = peer.transport == P2pPeerTransport.lan
          ? await _transfer.receiveLanFile(
              connection: await _lan.acceptIncomingRequest(peer),
              outputPath: outputPath,
              expectedSize: request.fileSize,
              onProgress: _onProgress,
              isCancelled: () => _cancelRequested,
            )
          : await _receiveBleFile(peer, request, outputPath);

      _receivedFiles.insert(
        0,
        P2pReceivedFile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          filename: request.fileName,
          size: request.fileSize,
          mimeType: request.mimeType,
          tempFileName: savedPath,
          tempFileBaseName: tempFileBaseName,
          receivedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _status = P2pStatus.completed;
    } catch (e) {
      _status = _cancelRequested ? P2pStatus.cancelled : P2pStatus.failed;
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _progress = null;
      _activeTransport = null;
      notifyListeners();
    }
  }

  Future<void> rejectIncomingRequest() async {
    final incoming = _incomingRequest;
    if (incoming == null) return;
    final (peer, _) = incoming;
    _incomingRequest = null;
    notifyListeners();
    try {
      if (peer.transport == P2pPeerTransport.lan) {
        await _lan.rejectIncomingRequest(peer);
      } else {
        await _discovery.respondToRequest(
          peer.bleDeviceId,
          P2pHandshakeResponse(
            accepted: false,
            receiverName: Platform.localHostname,
          ),
        );
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Sender flow
  // ---------------------------------------------------------------------

  void setPendingSendFile({
    required String path,
    required String name,
    required int size,
    required String mimeType,
  }) {
    _pendingSendFilePath = path;
    _pendingSendFileName = name;
    _pendingSendFileSize = size;
    _pendingSendMimeType = mimeType;
    notifyListeners();
  }

  void clearPendingSendFile() {
    _pendingSendFilePath = null;
    _pendingSendFileName = null;
    _pendingSendFileSize = null;
    _pendingSendMimeType = null;
    notifyListeners();
  }

  bool get hasPendingSendFile => _pendingSendFilePath != null;
  String? get pendingSendFileName => _pendingSendFileName;
  int? get pendingSendFileSize => _pendingSendFileSize;

  Future<void> startScanningForPeers() async {
    if (_role == P2pRole.receiving) {
      await stopReceiving();
    }
    _role = P2pRole.sending;
    _status = P2pStatus.scanning;
    _error = null;
    _peers = [];
    notifyListeners();

    try {
      await _peersSub?.cancel();
      _peersSub = _discovery.peersStream.listen((peers) {
        _setPeers(peers, P2pPeerTransport.ble);
        notifyListeners();
      });
      await _lanPeersSub?.cancel();
      _lanPeersSub = _lan.peersStream.listen((peers) {
        _setPeers(peers, P2pPeerTransport.lan);
        notifyListeners();
      });
      await _lan.startScanning();
      if (!Platform.isLinux) {
        try {
          await _discovery.startScan();
        } catch (e) {
          errorLog('[FastDropP2p] BLE scanning unavailable: $e');
        }
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _status = P2pStatus.failed;
      notifyListeners();
    }
  }

  Future<void> stopScanningForPeers() async {
    await _discovery.stopScan();
    await _lan.stopScanning();
    await _peersSub?.cancel();
    _peersSub = null;
    await _lanPeersSub?.cancel();
    _lanPeersSub = null;
    if (_role == P2pRole.sending && _status == P2pStatus.scanning) {
      _status = P2pStatus.idle;
    }
    notifyListeners();
  }

  /// Sends the pending file to [peer]: connects, handshakes, then streams
  /// bytes over the fastest available transport.
  Future<void> sendToPeer(P2pPeer peer, String senderName) async {
    final path = _pendingSendFilePath;
    final name = _pendingSendFileName;
    final size = _pendingSendFileSize;
    final mimeType = _pendingSendMimeType ?? 'application/octet-stream';
    if (path == null || name == null || size == null) return;

    _cancelRequested = false;
    _status = P2pStatus.handshaking;
    _error = null;
    notifyListeners();

    try {
      await _discovery.stopScan();
      await _lan.stopScanning();
      final localIps = await P2pTransferService.localIpAddresses();
      final request = P2pHandshakeRequest(
        senderName: senderName,
        candidateIps: localIps,
        lanPort: P2pProtocol.bleLanFallbackPort,
        fileName: name,
        fileSize: size,
        mimeType: mimeType,
      );
      if (peer.transport == P2pPeerTransport.lan) {
        final connection = await _lan.sendHandshake(peer, request);
        _status = P2pStatus.transferring;
        _progress = (0, size);
        notifyListeners();
        await _transfer.sendLanFile(
          connection: connection,
          filePath: path,
          fileSize: size,
          onProgress: _onProgress,
          isCancelled: () => _cancelRequested,
        );
        _activeTransport = P2pTransportKind.lan;
        _status = P2pStatus.completed;
        clearPendingSendFile();
        return;
      }
      final response = await _discovery.sendHandshake(
        bleDeviceId: peer.bleDeviceId,
        request: request,
      );

      if (!response.accepted) {
        _status = P2pStatus.failed;
        _error = 'Peer declined the transfer';
        notifyListeners();
        return;
      }

      _status = P2pStatus.transferring;
      _progress = (0, size);
      notifyListeners();

      _activeTransport = await _transfer.sendFile(
        discovery: _discovery,
        bleDeviceId: peer.bleDeviceId,
        receiverIps: response.candidateIps,
        receiverPort: response.lanPort,
        filePath: path,
        fileSize: size,
        onProgress: _onProgress,
        isCancelled: () => _cancelRequested,
      );

      _status = P2pStatus.completed;
      clearPendingSendFile();
    } catch (e) {
      _status = _cancelRequested ? P2pStatus.cancelled : P2pStatus.failed;
      _error = e.toString().replaceAll('Exception: ', '');
      _role = P2pRole.none;
    } finally {
      _progress = null;
      notifyListeners();
      if (peer.transport == P2pPeerTransport.ble) {
        await _discovery.disconnect(peer.bleDeviceId);
      }
    }
  }

  void cancelTransfer() {
    _cancelRequested = true;
    notifyListeners();
  }

  void _onProgress(int current, int total, P2pTransportKind transport) {
    _activeTransport = transport;
    _progress = (current, total);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (current >= total || now - _lastProgressNotifyMs >= 120) {
      _lastProgressNotifyMs = now;
      notifyListeners();
    }
  }

  Future<String> _receiveBleFile(
    P2pPeer peer,
    P2pHandshakeRequest request,
    String outputPath,
  ) async {
    final localIps = await P2pTransferService.localIpAddresses();
    return _transfer.receiveFile(
      discovery: _discovery,
      outputPath: outputPath,
      expectedSize: request.fileSize,
      onProgress: _onProgress,
      isCancelled: () => _cancelRequested,
      onReady: () => _discovery.respondToRequest(
        peer.bleDeviceId,
        P2pHandshakeResponse(
          accepted: true,
          receiverName: Platform.localHostname,
          candidateIps: localIps,
          lanPort: P2pProtocol.bleLanFallbackPort,
        ),
      ),
    );
  }

  void _setPeers(List<P2pPeer> peers, P2pPeerTransport transport) {
    _peers = [..._peers.where((peer) => peer.transport != transport), ...peers];
  }

  /// Removes a received file from the in-memory list. The caller (page) is
  /// responsible for deleting the backing temp file via its TempFileScope.
  void dismissReceivedFile(String id) {
    _receivedFiles.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  /// Removes all received files from the in-memory list. The caller (page)
  /// is responsible for deleting the backing temp files via its TempFileScope.
  void clearAllReceivedFiles() {
    _receivedFiles.clear();
    notifyListeners();
  }

  void resetToIdle() {
    _role = P2pRole.none;
    _status = P2pStatus.idle;
    _error = null;
    _progress = null;
    _activeTransport = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _incomingSub?.cancel();
    _advertisingErrorSub?.cancel();
    _lanPeersSub?.cancel();
    _lanIncomingSub?.cancel();
    _discovery.stopScan();
    _discovery.stopAdvertising();
    _discovery.dispose();
    _lan.dispose();
    _transfer.cancelReceive();
    super.dispose();
  }
}
