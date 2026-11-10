import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import 'api/x_session.dart';

/// Hands a logged-in session from a phone to a TV that cannot log in itself.
/// The TV listens on the LAN and shows a QR code holding its addresses and a
/// one-time AES key; the phone scans it and posts the session encrypted, so
/// nothing readable crosses the network and only the TV showing the code can
/// accept it.
class XPairingReceiver {
  static const String _scheme = 'toollab-x-pair';
  static const String _path = '/x-pair';

  final HttpServer _server;
  final SecretKey _key;
  final List<int> _keyBytes;
  final List<String> hosts;
  final Completer<XSession> _received = Completer<XSession>();

  XPairingReceiver._(this._server, this._key, this._keyBytes, this.hosts) {
    _server.listen(
      _handle,
      onError: (Object e) {
        debugLog('[XPairing] Server error: $e');
      },
    );
  }

  static Future<XPairingReceiver> start({
    @visibleForTesting InternetAddress? bindAddress,
  }) async {
    final server = await HttpServer.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      0,
    );
    final keyBytes = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    );
    final hosts = <String>[];
    for (final iface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    )) {
      for (final address in iface.addresses) {
        if (!address.isLoopback && !address.isLinkLocal) {
          hosts.add(address.address);
        }
      }
    }
    return XPairingReceiver._(server, SecretKey(keyBytes), keyBytes, hosts);
  }

  int get port => _server.port;

  Future<XSession> get session => _received.future;

  String get payload =>
      '$_scheme:${base64Url.encode(utf8.encode(jsonEncode({'h': hosts, 'p': port, 'k': base64Url.encode(_keyBytes)})))}';

  Future<void> _handle(HttpRequest request) async {
    if (request.method != 'POST' || request.uri.path != _path) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    try {
      final body = await utf8
          .decodeStream(request)
          .timeout(const Duration(seconds: 10));
      final box = SecretBox.fromConcatenation(
        base64.decode(body.trim()),
        nonceLength: 12,
        macLength: 16,
      );
      final clear = await AesGcm.with256bits().decrypt(box, secretKey: _key);
      final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final session = XSession.fromCookies(json.cast<String, String>());
      if (session == null) throw const FormatException('Incomplete session');
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      if (!_received.isCompleted) _received.complete(session);
    } catch (e) {
      // A wrong key fails the MAC check: someone else's code, or tampering.
      debugLog('[XPairing] Rejected pairing request: $e');
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
    }
  }

  Future<void> close() => _server.close(force: true);

  /// Sends [session] to the TV described by a scanned [payload]. Each address
  /// the TV listed is tried, since a TV can sit on more than one network.
  static Future<bool> send(String payload, XSession session) async {
    if (!payload.startsWith('$_scheme:')) {
      throw const FormatException('Not a ToolLab pairing code');
    }
    final json =
        jsonDecode(
              utf8.decode(
                base64Url.decode(payload.substring(_scheme.length + 1)),
              ),
            )
            as Map<String, dynamic>;
    final hosts = (json['h'] as List).cast<String>();
    final port = json['p'] as int;
    final key = SecretKey(base64Url.decode(json['k'] as String));
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(session.toJson())),
      secretKey: key,
    );
    final body = base64.encode(Uint8List.fromList(box.concatenation()));

    final client = await AppHttpClient.client;
    for (final host in hosts) {
      try {
        final res = await client
            .post(
              Uri(scheme: 'http', host: host, port: port, path: _path),
              body: body,
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == HttpStatus.ok) return true;
      } catch (e) {
        debugLog('[XPairing] $host:$port unreachable: $e');
      }
    }
    return false;
  }
}
