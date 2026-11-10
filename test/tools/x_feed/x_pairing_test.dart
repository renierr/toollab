import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/tools/x_feed/api/x_session.dart';
import 'package:tool_lab/tools/x_feed/x_pairing.dart';

const _session = XSession(authToken: 'auth', csrfToken: 'csrf');

// Loopback only: no LAN listener, no firewall prompt, no network access.
Future<XPairingReceiver> _start() async {
  final receiver = await XPairingReceiver.start(
    bindAddress: InternetAddress.loopbackIPv4,
  );
  addTearDown(receiver.close);
  return receiver;
}

/// [source]'s code, pointed at 127.0.0.1 and optionally another [port].
String _loopbackCode(XPairingReceiver source, {int? port}) {
  final payload = source.payload;
  final json =
      jsonDecode(
            utf8.decode(
              base64Url.decode(payload.substring(payload.indexOf(':') + 1)),
            ),
          )
          as Map<String, dynamic>;
  json['h'] = ['127.0.0.1'];
  if (port != null) json['p'] = port;
  return 'toollab-x-pair:${base64Url.encode(utf8.encode(jsonEncode(json)))}';
}

void main() {
  setUpAll(() => AppHttpClient.testClient = http.Client());
  tearDownAll(() => AppHttpClient.testClient = null);

  test('a scanned code delivers the session to the receiver', () async {
    final receiver = await _start();
    expect(
      await XPairingReceiver.send(_loopbackCode(receiver), _session),
      isTrue,
    );
    final received = await receiver.session;
    expect(received.authToken, 'auth');
    expect(received.csrfToken, 'csrf');
  });

  test('a code with another key is rejected', () async {
    final receiver = await _start();
    final other = await _start();
    final forged = _loopbackCode(other, port: receiver.port);
    expect(await XPairingReceiver.send(forged, _session), isFalse);
  });
}
