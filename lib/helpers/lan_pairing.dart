import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

class PairingProtocol {
  final String scheme;
  final String path;
  final String? kind;

  const PairingProtocol({required this.scheme, required this.path, this.kind});
}

/// A QR code carries a one-time key for encrypted local-network handoff.
class PairingReceiver {
  static const String _kindKey = 't';

  final HttpServer _server;
  final SecretKey _key;
  final List<int> _keyBytes;
  final PairingProtocol protocol;
  final bool Function(Map<String, dynamic>)? _validate;
  final List<String> hosts;
  final Completer<Map<String, dynamic>> _received =
      Completer<Map<String, dynamic>>();
  bool _accepted = false;

  PairingReceiver._(
    this._server,
    this._key,
    this._keyBytes,
    this.protocol,
    this.hosts,
    this._validate,
  ) {
    _server.listen(
      _handle,
      onError: (Object e) {
        debugLog('[PairingReceiver] Server error: $e');
      },
    );
  }

  static Future<PairingReceiver> start({
    required PairingProtocol protocol,
    bool Function(Map<String, dynamic>)? validate,
    InternetAddress? bindAddress,
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
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final address in iface.addresses) {
          if (!address.isLoopback && !address.isLinkLocal) {
            hosts.add(address.address);
          }
        }
      }
    } catch (_) {
      await server.close(force: true);
      rethrow;
    }
    return PairingReceiver._(
      server,
      SecretKey(keyBytes),
      keyBytes,
      protocol,
      hosts,
      validate,
    );
  }

  int get port => _server.port;

  Future<Map<String, dynamic>> get received => _received.future;

  String payload([Map<String, Object?> fields = const {}]) {
    final code = {
      'h': hosts,
      'p': port,
      'k': base64Url.encode(_keyBytes),
      if (protocol.kind != null) _kindKey: protocol.kind,
      ...fields,
    };
    return '${protocol.scheme}:${base64Url.encode(utf8.encode(jsonEncode(code)))}';
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.method != 'POST' ||
        request.uri.path != protocol.path ||
        _accepted) {
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
      if (_validate != null && !_validate(json)) {
        throw const FormatException('Invalid pairing data');
      }
      if (_accepted) {
        request.response.statusCode = HttpStatus.conflict;
        await request.response.close();
      } else {
        _accepted = true;
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        _received.complete(json);
      }
    } catch (e) {
      // A wrong key fails the MAC check: someone else's code, or tampering.
      debugLog('[PairingReceiver] Rejected pairing request: $e');
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
    }
  }

  Future<void> close() => _server.close(force: true);
}

/// A scanned code, split into the receiver's location and the fields it
/// published for the sender.
class PairingCode {
  final List<String> hosts;
  final int port;
  final SecretKey key;
  final PairingProtocol protocol;
  final Map<String, dynamic> fields;

  const PairingCode._(
    this.hosts,
    this.port,
    this.key,
    this.protocol,
    this.fields,
  );

  static PairingCode parse(
    String payload, {
    required PairingProtocol protocol,
  }) {
    if (!payload.startsWith('${protocol.scheme}:')) {
      throw const FormatException('Not a ToolLab pairing code');
    }
    final json =
        jsonDecode(
              utf8.decode(
                base64Url.decode(payload.substring(protocol.scheme.length + 1)),
              ),
            )
            as Map<String, dynamic>;
    if (protocol.kind != null &&
        json[PairingReceiver._kindKey] != protocol.kind) {
      throw const FormatException('Wrong pairing kind');
    }
    final fields = {...json}
      ..remove('h')
      ..remove('p')
      ..remove('k')
      ..remove(PairingReceiver._kindKey);
    return PairingCode._(
      (json['h'] as List).cast<String>(),
      json['p'] as int,
      SecretKey(base64Url.decode(json['k'] as String)),
      protocol,
      fields,
    );
  }
}

class PairingSender {
  PairingSender._();

  /// Sends [data] to the device described by [code]. Each address it listed is
  /// tried, since a TV can sit on more than one network.
  static Future<bool> send(PairingCode code, Map<String, Object?> data) async {
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: code.key,
    );
    final body = base64.encode(Uint8List.fromList(box.concatenation()));

    final client = await AppHttpClient.client;
    for (final host in code.hosts) {
      try {
        final res = await client
            .post(
              Uri(
                scheme: 'http',
                host: host,
                port: code.port,
                path: code.protocol.path,
              ),
              body: body,
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == HttpStatus.ok) return true;
      } catch (e) {
        debugLog('[PairingSender] $host:${code.port} unreachable: $e');
      }
    }
    return false;
  }
}
