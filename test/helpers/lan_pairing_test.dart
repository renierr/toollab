import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/lan_pairing.dart';
import 'package:tool_lab/services/app_http_client.dart';

const _protocol = PairingProtocol(
  scheme: 'toollab-pair',
  path: '/pair',
  kind: 'test',
);

// Loopback only: no LAN listener, no firewall prompt, no network access.
Future<PairingReceiver> _start() async {
  final receiver = await PairingReceiver.start(
    protocol: _protocol,
    bindAddress: InternetAddress.loopbackIPv4,
  );
  addTearDown(receiver.close);
  return receiver;
}

/// [source]'s code, pointed at 127.0.0.1 and optionally another [port].
String _loopbackCode(
  PairingReceiver source, {
  Map<String, Object?> fields = const {},
  int? port,
}) {
  final payload = source.payload(fields);
  final json =
      jsonDecode(
            utf8.decode(
              base64Url.decode(payload.substring(payload.indexOf(':') + 1)),
            ),
          )
          as Map<String, dynamic>;
  json['h'] = ['127.0.0.1'];
  if (port != null) json['p'] = port;
  return '${_protocol.scheme}:'
      '${base64Url.encode(utf8.encode(jsonEncode(json)))}';
}

void main() {
  setUpAll(() => AppHttpClient.testClient = http.Client());
  tearDownAll(() => AppHttpClient.testClient = null);

  test('a scanned code delivers the data to the receiver', () async {
    final receiver = await _start();
    final code = PairingCode.parse(
      _loopbackCode(receiver),
      protocol: _protocol,
    );
    expect(await PairingSender.send(code, {'value': 'secret'}), isTrue);
    expect(await receiver.received, {'value': 'secret'});
  });

  test('a code with another key is rejected', () async {
    final receiver = await _start();
    final other = await _start();
    final forged = PairingCode.parse(
      _loopbackCode(other, port: receiver.port),
      protocol: _protocol,
    );
    expect(await PairingSender.send(forged, {'value': 'secret'}), isFalse);
  });

  test('a code for another kind is refused', () async {
    final receiver = await _start();
    expect(
      () => PairingCode.parse(
        _loopbackCode(receiver),
        protocol: const PairingProtocol(
          scheme: 'toollab-pair',
          path: '/pair',
          kind: 'other',
        ),
      ),
      throwsFormatException,
    );
  });

  test('fields published by the receiver reach the sender', () async {
    final receiver = await _start();
    final code = PairingCode.parse(
      _loopbackCode(receiver, fields: {'c': 'client', 's': 'state'}),
      protocol: _protocol,
    );
    expect(code.fields, {'c': 'client', 's': 'state'});
  });
}
