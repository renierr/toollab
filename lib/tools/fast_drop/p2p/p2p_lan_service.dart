import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'p2p_models.dart';
import 'p2p_protocol.dart';

typedef P2pLanIncomingRequest = (P2pPeer peer, P2pHandshakeRequest request);

/// Owns the only subscription to a TCP socket. Bytes received after the JSON
/// handshake line are buffered and exposed as the raw transfer stream.
class P2pLanConnection {
  final Socket socket;

  /// Pausing the socket while the consumer is busy is what keeps received
  /// bytes from piling up in this controller's queue when storage is slower
  /// than the network.
  late final StreamController<List<int>> _bytesController = StreamController(
    onPause: () => _subscription.pause(),
    onResume: () => _subscription.resume(),
  );
  final List<int> _handshakeBuffer = [];
  late final StreamSubscription<List<int>> _subscription;
  Completer<String>? _lineCompleter;
  var _handshakeComplete = false;

  P2pLanConnection(this.socket) {
    _subscription = socket.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  Stream<List<int>> get bytes => _bytesController.stream;

  Future<String> readJsonLine() {
    if (_lineCompleter != null) return _lineCompleter!.future;
    _lineCompleter = Completer<String>();
    _consumeHandshakeBuffer();
    return _lineCompleter!.future;
  }

  void _onData(List<int> data) {
    if (_handshakeComplete) {
      _bytesController.add(data);
      return;
    }
    _handshakeBuffer.addAll(data);
    _consumeHandshakeBuffer();
  }

  void _consumeHandshakeBuffer() {
    final newline = _handshakeBuffer.indexOf(10);
    if (newline < 0 || _lineCompleter == null) return;
    final line = utf8.decode(_handshakeBuffer.sublist(0, newline)).trimRight();
    final remaining = _handshakeBuffer.sublist(newline + 1);
    _handshakeBuffer.clear();
    _handshakeComplete = true;
    _lineCompleter!.complete(line);
    if (remaining.isNotEmpty) _bytesController.add(remaining);
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (_lineCompleter case final completer? when !completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    _bytesController.addError(error, stackTrace);
  }

  void _onDone() {
    if (_lineCompleter case final completer? when !completer.isCompleted) {
      completer.completeError(Exception('Connection closed during handshake'));
    }
    _bytesController.close();
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _bytesController.close();
    await socket.close();
  }
}

/// LAN discovery and direct socket handshake using only dart:io.
class P2pLanService {
  static const _multicastChannel = MethodChannel(
    'de.renier.tool_lab/multicast',
  );
  final String _instanceId = Random.secure().nextInt(1 << 32).toRadixString(16);
  RawDatagramSocket? _discoverySocket;
  ServerSocket? _transferServer;
  Timer? _announceTimer;
  String? _deviceName;
  final Map<String, P2pLanConnection> _pendingConnections = {};
  final _peersController = StreamController<List<P2pPeer>>.broadcast();
  final _incomingController =
      StreamController<P2pLanIncomingRequest>.broadcast();
  final Map<String, P2pPeer> _peers = {};

  Stream<List<P2pPeer>> get peersStream => _peersController.stream;
  Stream<P2pLanIncomingRequest> get incomingRequests =>
      _incomingController.stream;

  Future<void> startReceiving(String deviceName) async {
    _deviceName = deviceName;
    await _startDiscovery();
    _transferServer ??= await ServerSocket.bind(
      InternetAddress.anyIPv4,
      P2pProtocol.lanPort,
      shared: true,
    );
    _transferServer!.listen(_handleTransferConnection);
    _announce();
    _announceTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _announce(),
    );
  }

  Future<void> startScanning() async {
    await _startDiscovery();
    _peers.clear();
    _peersController.add(const []);
    _sendDiscovery();
  }

  Future<void> _startDiscovery() async {
    if (_discoverySocket != null) return;
    if (Platform.isAndroid) {
      await _multicastChannel.invokeMethod<void>('setEnabled', {
        'enabled': true,
      });
    }
    _discoverySocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      P2pProtocol.lanDiscoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _discoverySocket!.broadcastEnabled = true;
    _discoverySocket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = _discoverySocket!.receive()) != null) {
        _handleDatagram(datagram!);
      }
    });
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final message =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (message['app'] != 'tool_lab_fast_drop') return;
      if (message['type'] == 'discover' && _deviceName != null) {
        _sendAnnouncement(datagram.address);
        return;
      }
      if (message['type'] != 'announce') return;
      final name = message['name'] as String?;
      if (name == null || message['instanceId'] == _instanceId) return;
      final peer = P2pPeer(
        id: 'lan:${datagram.address.address}',
        name: name,
        transport: P2pPeerTransport.lan,
        lanAddress: datagram.address.address,
      );
      _peers[peer.id] = peer;
      _peersController.add(_peers.values.toList());
    } catch (e) {
      debugPrint('[P2pLan] invalid discovery datagram: $e');
    }
  }

  void _sendDiscovery() =>
      _sendDatagram({'app': 'tool_lab_fast_drop', 'type': 'discover'});

  void _announce() => _sendDatagram({
    'app': 'tool_lab_fast_drop',
    'type': 'announce',
    'name': _deviceName,
    'instanceId': _instanceId,
  });

  void _sendAnnouncement(InternetAddress address) => _sendDatagram({
    'app': 'tool_lab_fast_drop',
    'type': 'announce',
    'name': _deviceName,
    'instanceId': _instanceId,
  }, address);

  void _sendDatagram(Map<String, dynamic> message, [InternetAddress? address]) {
    _discoverySocket?.send(
      utf8.encode(jsonEncode(message)),
      address ?? InternetAddress('255.255.255.255'),
      P2pProtocol.lanDiscoveryPort,
    );
  }

  Future<void> _handleTransferConnection(Socket socket) async {
    final connection = P2pLanConnection(socket);
    try {
      final line = await connection.readJsonLine().timeout(
        const Duration(seconds: 15),
      );
      final request = P2pHandshakeRequest.fromJson(
        jsonDecode(line) as Map<String, dynamic>,
      );
      final peer = P2pPeer(
        id: 'lan:${socket.remoteAddress.address}',
        name: request.senderName,
        transport: P2pPeerTransport.lan,
        lanAddress: socket.remoteAddress.address,
      );
      await _pendingConnections[peer.id]?.close();
      _pendingConnections[peer.id] = connection;
      _incomingController.add((peer, request));
    } catch (e) {
      debugPrint('[P2pLan] invalid handshake: $e');
      await connection.close();
    }
  }

  Future<P2pLanConnection> sendHandshake(
    P2pPeer peer,
    P2pHandshakeRequest request,
  ) async {
    final address = peer.lanAddress;
    if (address == null) throw Exception('LAN peer has no address');
    final socket = await Socket.connect(
      address,
      P2pProtocol.lanPort,
      timeout: const Duration(seconds: 10),
    );
    final connection = P2pLanConnection(socket);
    try {
      socket.write('${request.encode()}\n');
      await socket.flush();
      final line = await connection.readJsonLine().timeout(
        const Duration(seconds: 30),
      );
      final response = P2pHandshakeResponse.fromJson(
        jsonDecode(line) as Map<String, dynamic>,
      );
      if (!response.accepted) throw Exception('Peer declined the transfer');
      return connection;
    } catch (_) {
      await connection.close();
      rethrow;
    }
  }

  Future<P2pLanConnection> acceptIncomingRequest(P2pPeer peer) async {
    final connection = _pendingConnections.remove(peer.id);
    if (connection == null) throw Exception('Transfer request expired');
    connection.socket.write(
      '${P2pHandshakeResponse(accepted: true, receiverName: _deviceName ?? Platform.localHostname).encode()}\n',
    );
    await connection.socket.flush();
    return connection;
  }

  Future<void> rejectIncomingRequest(P2pPeer peer) async {
    final connection = _pendingConnections.remove(peer.id);
    if (connection == null) return;
    connection.socket.write(
      '${P2pHandshakeResponse(accepted: false, receiverName: _deviceName ?? Platform.localHostname).encode()}\n',
    );
    await connection.socket.flush();
    await connection.close();
  }

  Future<void> stopReceiving() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    await _transferServer?.close();
    _transferServer = null;
    for (final connection in _pendingConnections.values) {
      await connection.close();
    }
    _pendingConnections.clear();
    _deviceName = null;
    _closeDiscoverySocket();
  }

  Future<void> stopScanning() async {
    _peers.clear();
    _closeDiscoverySocket();
  }

  void _closeDiscoverySocket() {
    _discoverySocket?.close();
    _discoverySocket = null;
    if (Platform.isAndroid) {
      unawaited(
        _multicastChannel.invokeMethod<void>('setEnabled', {'enabled': false}),
      );
    }
  }

  Future<void> dispose() async {
    await stopReceiving();
    _closeDiscoverySocket();
    await _peersController.close();
    await _incomingController.close();
  }
}
