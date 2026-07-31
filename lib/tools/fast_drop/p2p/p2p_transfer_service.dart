import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'p2p_discovery_service.dart';
import 'p2p_lan_service.dart';
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
    required Future<void> Function() onReady,
  }) async {
    final file = File(outputPath);
    final sink = file.openWrite();
    int received = 0;
    final completer = Completer<String>();
    P2pTransportKind? activeTransport;
    bool isFinishing = false;

    void fail(Object error, [StackTrace? stackTrace]) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }

    void checkCancelled() {
      if (isCancelled()) {
        throw Exception('Transfer cancelled');
      }
    }

    Future<void> finishIfDone() async {
      if (received >= expectedSize && !completer.isCompleted && !isFinishing) {
        isFinishing = true;
        await sink.flush();
        await sink.close();
        completer.complete(outputPath);
      }
    }

    // LAN path: best-effort server bind (may fail on restricted networks).
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        P2pProtocol.bleLanFallbackPort,
        shared: true,
      );
      _serverSub = _serverSocket!.listen((client) {
        if (activeTransport != null) {
          client.destroy();
          return;
        }
        activeTransport = P2pTransportKind.lan;
        unawaited(
          Future(() async {
            try {
              await sink.addStream(
                _boundedChunks(
                  source: client,
                  expectedSize: expectedSize,
                  transport: P2pTransportKind.lan,
                  onProgress: onProgress,
                  isCancelled: isCancelled,
                  onReceived: (value) => received = value,
                ),
              );
              await finishIfDone();
              if (!completer.isCompleted && !isFinishing) {
                fail(Exception('Connection closed before transfer completed'));
              }
            } catch (e, stackTrace) {
              fail(e, stackTrace);
            } finally {
              client.destroy();
            }
          }),
        );
      });
    } catch (e) {
      debugPrint('[P2pTransfer] LAN server bind failed, BLE-only: $e');
    }

    // BLE fallback path.
    discovery.setDataWriteHandler((deviceId, chunk) async {
      try {
        if (activeTransport == P2pTransportKind.lan) return;
        activeTransport = P2pTransportKind.ble;
        if (isCancelled()) {
          fail(Exception('Transfer cancelled'));
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, expectedSize, P2pTransportKind.ble);
        unawaited(discovery.sendAck(deviceId, received));
        await finishIfDone();
      } catch (e, stackTrace) {
        fail(e, stackTrace);
      }
    });

    checkCancelled();
    await onReady();
    try {
      await completer.future;
      return outputPath;
    } finally {
      await _closeServer();
    }
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

  /// Wraps [source] so it stops at [expectedSize], reports progress and
  /// honours cancellation. Being an `async*` generator, a pause from the
  /// consuming file sink propagates back to the socket — bytes are never
  /// buffered in RAM waiting for slow storage.
  static Stream<List<int>> _boundedChunks({
    required Stream<List<int>> source,
    required int expectedSize,
    required P2pTransportKind transport,
    required P2pProgressCallback onProgress,
    required bool Function() isCancelled,
    required void Function(int received) onReceived,
  }) async* {
    var received = 0;
    await for (final data in source) {
      if (isCancelled()) throw Exception('Transfer cancelled');
      final remaining = expectedSize - received;
      if (remaining <= 0) break;
      final chunk = data.length > remaining ? data.sublist(0, remaining) : data;
      received += chunk.length;
      onReceived(received);
      onProgress(received, expectedSize, transport);
      yield chunk;
      if (received >= expectedSize) break;
    }
  }

  /// Copies a LAN socket already authenticated by the direct LAN handshake.
  Future<String> receiveLanFile({
    required P2pLanConnection connection,
    required String outputPath,
    required int expectedSize,
    required P2pProgressCallback onProgress,
    required bool Function() isCancelled,
  }) async {
    final sink = File(outputPath).openWrite();
    var received = 0;
    try {
      await sink.addStream(
        _boundedChunks(
          source: connection.bytes,
          expectedSize: expectedSize,
          transport: P2pTransportKind.lan,
          onProgress: onProgress,
          isCancelled: isCancelled,
          onReceived: (value) => received = value,
        ),
      );
      if (received != expectedSize) {
        throw Exception('Connection closed before transfer completed');
      }
      await sink.flush();
      return outputPath;
    } finally {
      await sink.close();
      await connection.close();
    }
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

  Future<void> sendLanFile({
    required P2pLanConnection connection,
    required String filePath,
    required int fileSize,
    required P2pProgressCallback onProgress,
    required bool Function() isCancelled,
  }) => _sendOverLan(
    socket: connection.socket,
    filePath: filePath,
    fileSize: fileSize,
    onProgress: onProgress,
    isCancelled: isCancelled,
  );

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
    try {
      // addStream keeps the socket's write buffer bounded (it pauses the file
      // read when the socket is full) while still pipelining, unlike a
      // flush-per-chunk loop which caps throughput at one chunk per RTT.
      await socket.addStream(
        File(filePath).openRead().map((chunk) {
          if (isCancelled()) {
            throw Exception('Transfer cancelled');
          }
          sent += chunk.length;
          onProgress(sent, fileSize, P2pTransportKind.lan);
          return chunk;
        }),
      );
      await socket.flush();
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
