import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'p2p_models.dart';
import 'p2p_protocol.dart';

/// Handles BLE discovery and the small handshake exchange used to find a
/// nearby peer and agree on a transfer (file manifest + candidate IPs).
///
/// Two roles:
/// - Receiver: advertises the Fast Drop service (peripheral role) and waits
///   for an incoming handshake write, exposing it via [onIncomingRequest].
/// - Sender: scans for advertising peers (central role), connects to one and
///   writes a handshake request, then awaits the response via
///   [sendHandshake].
///
/// Handshake messages are almost always bigger than the default (and
/// sometimes even the negotiated) GATT payload size, so both directions use
/// [P2pProtocol.chunkWithLengthPrefix] / [P2pChunkReassembler] rather than
/// relying on the platform to perform an automatic GATT "long write".
class P2pDiscoveryService {
  StreamSubscription<BleDevice>? _scanSub;
  final Map<String, P2pPeer> _peers = {};
  final _peersController = StreamController<List<P2pPeer>>.broadcast();
  final _incomingRequestController =
      StreamController<
        (String bleDeviceId, P2pHandshakeRequest request)
      >.broadcast();

  Completer<Uint8List>? _pendingResponse;
  StreamSubscription<Uint8List>? _handshakeResponseSub;
  final P2pChunkReassembler _requestReassembler = P2pChunkReassembler();
  final P2pChunkReassembler _responseReassembler = P2pChunkReassembler();

  /// Safe per-write payload size for the central (sender) role, updated
  /// once an MTU has been negotiated with the connected peripheral.
  int _centralChunkSize = P2pProtocol.defaultSafeChunkSize;

  Stream<List<P2pPeer>> get peersStream => _peersController.stream;

  /// Emits `(bleDeviceId, request)` whenever a sender writes a handshake
  /// request while we're advertising as a receiver.
  Stream<(String, P2pHandshakeRequest)> get onIncomingRequest =>
      _incomingRequestController.stream;

  Future<void> requestPermissions() async {
    try {
      await UniversalBle.requestPermissions(withAndroidFineLocation: false);
    } catch (e) {
      debugPrint('[P2pDiscovery] permission request failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Receiver role (peripheral / GATT server)
  // ---------------------------------------------------------------------

  Future<void> startAdvertisingAsReceiver(String deviceName) async {
    // Central and peripheral roles don't reliably coexist on every BLE
    // stack — make sure we're not still scanning from a previous "send"
    // attempt before becoming a peripheral.
    await stopScan();
    _requestReassembler.clear();

    await requestPermissions();

    UniversalBlePeripheral.setWriteRequestHandlers((
      deviceId,
      characteristicId,
      offset,
      value,
    ) {
      if (characteristicId.toLowerCase() ==
              P2pProtocol.handshakeCharUuid.toLowerCase() &&
          value != null) {
        _handleHandshakeWriteChunk(deviceId, value);
      }
      return PeripheralWriteRequestResult();
    });

    await UniversalBlePeripheral.clearServices();
    await UniversalBlePeripheral.addService(
      BlePeripheralService(
        uuid: P2pProtocol.serviceUuid,
        characteristics: [
          BlePeripheralCharacteristic(
            uuid: P2pProtocol.handshakeCharUuid,
            properties: const [
              CharacteristicProperty.write,
              CharacteristicProperty.notify,
            ],
            permissions: const [PeripheralAttributePermission.writeable],
          ),
          BlePeripheralCharacteristic(
            uuid: P2pProtocol.dataCharUuid,
            properties: const [CharacteristicProperty.write],
            permissions: const [PeripheralAttributePermission.writeable],
          ),
          BlePeripheralCharacteristic(
            uuid: P2pProtocol.ackCharUuid,
            properties: const [CharacteristicProperty.notify],
            permissions: const [PeripheralAttributePermission.readable],
          ),
        ],
      ),
    );

    try {
      await UniversalBlePeripheral.startAdvertising(
        services: [P2pProtocol.serviceUuid],
        localName: deviceName,
      );
    } catch (e) {
      // Some platforms (e.g. Windows' GattServiceProvider) reject a
      // localName in the advertisement — retry without it.
      debugPrint(
        '[P2pDiscovery] advertising with localName failed, retrying '
        'without it: $e',
      );
      await UniversalBlePeripheral.startAdvertising(
        services: [P2pProtocol.serviceUuid],
      );
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await UniversalBlePeripheral.stopAdvertising();
    } catch (_) {}
  }

  void _handleHandshakeWriteChunk(String deviceId, Uint8List chunk) {
    try {
      final complete = _requestReassembler.feed(deviceId, chunk);
      if (complete == null) return;
      final json = jsonDecode(utf8.decode(complete)) as Map<String, dynamic>;
      final request = P2pHandshakeRequest.fromJson(json);
      _incomingRequestController.add((deviceId, request));
    } catch (e) {
      debugPrint('[P2pDiscovery] failed to parse handshake request: $e');
      _requestReassembler.reset(deviceId);
    }
  }

  /// Sends the receiver's decision back to the sender over the handshake
  /// characteristic (peripheral notify), chunked to fit the link's actual
  /// notify payload limit.
  Future<void> respondToRequest(
    String bleDeviceId,
    P2pHandshakeResponse response,
  ) async {
    final payload = Uint8List.fromList(utf8.encode(response.encode()));
    int chunkSize = P2pProtocol.defaultSafeChunkSize;
    try {
      final maxLen = await UniversalBlePeripheral.getMaximumNotifyLength(
        bleDeviceId,
      );
      if (maxLen != null && maxLen > 8) chunkSize = maxLen;
    } catch (_) {}

    final chunks = P2pProtocol.chunkWithLengthPrefix(
      payload,
      chunkSize: chunkSize,
    );
    for (final chunk in chunks) {
      await UniversalBlePeripheral.updateCharacteristicValue(
        characteristicId: P2pProtocol.handshakeCharUuid,
        value: chunk,
        deviceId: bleDeviceId,
      );
    }
  }

  /// Chunk data written by a connected central (BLE fallback receive path).
  /// File-data chunks don't need length-prefix framing — only cumulative
  /// byte count matters, which the caller tracks against the known file
  /// size from the handshake manifest.
  void setDataWriteHandler(
    void Function(String deviceId, Uint8List chunk) onChunk,
  ) {
    UniversalBlePeripheral.setWriteRequestHandlers((
      deviceId,
      characteristicId,
      offset,
      value,
    ) {
      final id = characteristicId.toLowerCase();
      if (id == P2pProtocol.handshakeCharUuid.toLowerCase() && value != null) {
        _handleHandshakeWriteChunk(deviceId, value);
      } else if (id == P2pProtocol.dataCharUuid.toLowerCase() &&
          value != null) {
        onChunk(deviceId, value);
      }
      return PeripheralWriteRequestResult();
    });
  }

  Future<void> sendAck(String bleDeviceId, int chunksReceived) async {
    final bytes = ByteData(4)..setUint32(0, chunksReceived, Endian.little);
    try {
      await UniversalBlePeripheral.updateCharacteristicValue(
        characteristicId: P2pProtocol.ackCharUuid,
        value: bytes.buffer.asUint8List(),
        deviceId: bleDeviceId,
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Sender role (central / scanner)
  // ---------------------------------------------------------------------

  Future<void> startScan() async {
    // See startAdvertisingAsReceiver — avoid overlapping central+peripheral.
    await stopAdvertising();

    await requestPermissions();
    _peers.clear();
    await _scanSub?.cancel();
    _scanSub = UniversalBle.scanStream.listen(
      _onScanResult,
      onError: (e) => debugPrint('[P2pDiscovery] scan error: $e'),
    );
    await UniversalBle.startScan();
  }

  Future<void> stopScan() async {
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  void _onScanResult(BleDevice device) {
    final services = device.services.map((s) => s.toLowerCase()).toList();
    if (!services.contains(P2pProtocol.serviceUuid.toLowerCase())) return;
    final peer = P2pPeer(
      bleDeviceId: device.deviceId,
      name: (device.name?.isNotEmpty ?? false) ? device.name! : 'Nearby device',
      rssi: device.rssi ?? 0,
    );
    _peers[peer.bleDeviceId] = peer;
    _peersController.add(_peers.values.toList());
  }

  /// Safe per-write payload size for the currently connected central link,
  /// established during [sendHandshake]. Reused by the BLE-fallback file
  /// transfer so it doesn't exceed the negotiated MTU either.
  int get negotiatedChunkSize => _centralChunkSize;

  /// Connects to [bleDeviceId], writes the handshake request and waits for
  /// the receiver's response (or times out).
  Future<P2pHandshakeResponse> sendHandshake({
    required String bleDeviceId,
    required P2pHandshakeRequest request,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await UniversalBle.connect(bleDeviceId);
    final services = await UniversalBle.discoverServices(bleDeviceId);
    final service = services.firstWhere(
      (s) => s.uuid.toLowerCase() == P2pProtocol.serviceUuid.toLowerCase(),
      orElse: () => throw Exception('Peer does not expose Fast Drop service'),
    );

    _centralChunkSize = P2pProtocol.defaultSafeChunkSize;
    try {
      final mtu = await UniversalBle.requestMtu(bleDeviceId, 247);
      if (mtu > 3) {
        _centralChunkSize = mtu - 3;
      }
    } catch (e) {
      debugPrint('[P2pDiscovery] MTU request failed, using default: $e');
    }

    _pendingResponse = Completer<Uint8List>();
    _responseReassembler.reset(bleDeviceId);

    await _handshakeResponseSub?.cancel();
    _handshakeResponseSub =
        UniversalBle.characteristicValueStream(
          bleDeviceId,
          P2pProtocol.handshakeCharUuid,
        ).listen((value) {
          final complete = _responseReassembler.feed(bleDeviceId, value);
          if (complete != null &&
              _pendingResponse != null &&
              !_pendingResponse!.isCompleted) {
            _pendingResponse!.complete(complete);
          }
        });

    try {
      await UniversalBle.subscribeNotifications(
        bleDeviceId,
        service.uuid,
        P2pProtocol.handshakeCharUuid,
      );

      final payload = Uint8List.fromList(utf8.encode(request.encode()));
      final chunks = P2pProtocol.chunkWithLengthPrefix(
        payload,
        chunkSize: _centralChunkSize,
      );
      for (final chunk in chunks) {
        await UniversalBle.write(
          bleDeviceId,
          service.uuid,
          P2pProtocol.handshakeCharUuid,
          chunk,
          withoutResponse: false,
        );
      }

      final raw = await _pendingResponse!.future.timeout(timeout);
      final json = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      return P2pHandshakeResponse.fromJson(json);
    } finally {
      await _handshakeResponseSub?.cancel();
      _handshakeResponseSub = null;
      _pendingResponse = null;
      _responseReassembler.reset(bleDeviceId);
    }
  }

  Future<void> disconnect(String bleDeviceId) async {
    try {
      await UniversalBle.disconnect(bleDeviceId);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _scanSub?.cancel();
    await _peersController.close();
    await _incomingRequestController.close();
  }
}
