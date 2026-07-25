import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'p2p_discovery_service.dart';
import 'p2p_models.dart';
import 'p2p_protocol.dart';

/// Progress callback: bytes moved so far, total expected, transport used.
typedef P2pProgressCallback =
    void Function(int current, int total, P2pTransportKind transport);

/// Moves file bytes between two already-handshaken peers, picking the
/// fastest available path: a direct TCP socket if both devices are
/// reachable on the same network, otherwise a slower chunked transfer over
/// the BLE GATT data characteristic.
///
/// The file manifest (name/size) is assumed to already be known by both
/// sides via the BLE handshake — this class only moves raw bytes.
class P2pTransferService {
  /// All non-loopback IPv4 addresses of this device, used as LAN connect
  /// candidates advertised to the peer during handshake.
  static Future<List<String>> localIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      return interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .toList();
    } catch (e) {
      debugPrint('[P2pTransfer] failed to list local IPs: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------
  // Receiver side
  // ---------------------------------------------------------------------

  ServerSocket? _serverSocket;
  StreamSubscription<Socket>? _serverSub;

  /// Starts listening for an incoming LAN transfer and arms the BLE
  /// fallback data-write handler. Completes with the output file path once
  /// [expectedSize] bytes have arrived via either channel, or throws if
  /// cancelled.
  Future<String> receiveFile({
    required P2pDiscoveryService discovery,
    required String outputPath,
    required int expectedSize,
    required P2pProgressCallback onProgress,
    required bool Function() isCancelled,
  }) async {
    final file = File(outputPath);
    final sink = file.openWrite();
    int received = 0;
    final completer = Completer<String>();
    P2pTransportKind? activeTransport;

    void checkCancelled() {
      if (isCancelled()) {
        throw Exception('Transfer cancelled');
      }
    }

    Future<void> finishIfDone() async {
      if (received >= expectedSize && !completer.isCompleted) {
        await sink.flush();
        await sink.close();
        completer.complete(outputPath);
      }
    }

    // LAN path: best-effort server bind (may fail on restricted networks).
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        P2pProtocol.lanPort,
        shared: true,
      );
      _serverSub = _serverSocket!.listen((client) {
        if (activeTransport != null) {
          client.destroy();
          return;
        }
        activeTransport = P2pTransportKind.lan;
        client.listen(
          (data) {
            if (isCancelled()) {
              client.destroy();
              return;
            }
            sink.add(data);
            received += data.length;
            onProgress(received, expectedSize, P2pTransportKind.lan);
            unawaited(finishIfDone());
          },
          onError: (e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () {
            unawaited(
              finishIfDone().then((_) {
                if (!completer.isCompleted) {
                  completer.completeError(
                    Exception('Connection closed before transfer completed'),
                  );
                }
              }),
            );
          },
        );
      });
    } catch (e) {
      debugPrint('[P2pTransfer] LAN server bind failed, BLE-only: $e');
    }

    // BLE fallback path.
    discovery.setDataWriteHandler((deviceId, chunk) async {
      if (activeTransport == P2pTransportKind.lan) return;
      activeTransport = P2pTransportKind.ble;
      if (isCancelled()) return;
      sink.add(chunk);
      received += chunk.length;
      onProgress(received, expectedSize, P2pTransportKind.ble);
      unawaited(discovery.sendAck(deviceId, received));
      await finishIfDone();
    });

    checkCancelled();
    await completer.future;
    await _closeServer();
    return outputPath;
  }

  Future<void> _closeServer() async {
    await _serverSub?.cancel();
    _serverSub = null;
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> cancelReceive() async {
    await _closeServer();
  }

  // ---------------------------------------------------------------------
  // Sender side
  // ---------------------------------------------------------------------

  /// Tries the fastest available path to move [filePath] to the peer:
  /// direct LAN socket first, BLE GATT chunking as fallback.
  Future<P2pTransportKind> sendFile({
    required P2pDiscoveryService discovery,
    required String bleDeviceId,
    required List<String> receiverIps,
    required int receiverPort,
    required String filePath,
    required int fileSize,
    required P2pProgressCallback onProgress,
    required bool Function() isCancelled,
  }) async {
    final lanSocket = await _tryConnectLan(receiverIps, receiverPort);
    if (lanSocket != null) {
      await _sendOverLan(
        socket: lanSocket,
        filePath: filePath,
        fileSize: fileSize,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      return P2pTransportKind.lan;
    }

    await _sendOverBle(
      bleDeviceId: bleDeviceId,
      chunkSize: discovery.negotiatedChunkSize,
      filePath: filePath,
      fileSize: fileSize,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return P2pTransportKind.ble;
  }

  Future<Socket?> _tryConnectLan(List<String> ips, int port) async {
    if (ips.isEmpty) return null;
    final completer = Completer<Socket?>();
    var pending = ips.length;
    final sockets = <Socket>[];

    for (final ip in ips) {
      unawaited(
        Socket.connect(ip, port, timeout: P2pProtocol.lanConnectAttemptTimeout)
            .then((socket) {
              sockets.add(socket);
              if (!completer.isCompleted) {
                completer.complete(socket);
              } else {
                socket.destroy();
              }
            })
            .catchError((_) {
              pending--;
              if (pending == 0 && !completer.isCompleted) {
                completer.complete(null);
              }
            }),
      );
    }

    try {
      return await completer.future.timeout(
        P2pProtocol.lanConnectOverallTimeout,
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendOverLan({
    required Socket socket,
    required String filePath,
    required int fileSize,
    required P2pProgressCallback onProgress,
    required bool Function() isCancelled,
  }) async {
    int sent = 0;
    final stream = File(filePath).openRead();
    try {
      await for (final chunk in stream) {
        if (isCancelled()) {
          throw Exception('Transfer cancelled');
        }
        socket.add(chunk);
        await socket.flush();
        sent += chunk.length;
        onProgress(sent, fileSize, P2pTransportKind.lan);
      }
    } finally {
      await socket.close();
    }
  }

  Future<void> _sendOverBle({
    required String bleDeviceId,
    required int chunkSize,
    required String filePath,
    required int fileSize,
    required P2pProgressCallback onProgress,
    required bool Function() isCancelled,
  }) async {
    final services = await UniversalBle.discoverServices(bleDeviceId);
    final service = services.firstWhere(
      (s) => s.uuid.toLowerCase() == P2pProtocol.serviceUuid.toLowerCase(),
      orElse: () => throw Exception('Peer service not found'),
    );

    final safeChunkSize = chunkSize < 8 ? 8 : chunkSize;
    int sent = 0;
    final raf = await File(filePath).open();
    try {
      while (sent < fileSize) {
        if (isCancelled()) {
          throw Exception('Transfer cancelled');
        }
        final remaining = fileSize - sent;
        final chunkLen = remaining < safeChunkSize ? remaining : safeChunkSize;
        final chunk = await raf.read(chunkLen);
        await UniversalBle.write(
          bleDeviceId,
          service.uuid,
          P2pProtocol.dataCharUuid,
          Uint8List.fromList(chunk),
          withoutResponse: false,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('BLE write timed out'),
        );
        sent += chunk.length;
        onProgress(sent, fileSize, P2pTransportKind.ble);
      }
    } finally {
      await raf.close();
    }
  }
}
