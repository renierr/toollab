import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
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

  test('an old phone can send to the new receiver', () async {
    final receiver = await _start();
    final payload = _loopbackCode(receiver);
    expect(payload, startsWith('toollab-x-pair:'));
    final data =
        jsonDecode(utf8.decode(base64Url.decode(payload.split(':')[1])))
            as Map<String, dynamic>;
    expect(data.keys.toSet(), {'h', 'p', 'k'});
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(_session.toJson())),
      secretKey: SecretKey(base64Url.decode(data['k'] as String)),
    );
    final response = await http.post(
      Uri.parse('http://127.0.0.1:${receiver.port}/x-pair'),
      body: base64.encode(box.concatenation()),
    );
    expect(response.statusCode, 200);
    expect((await receiver.session).authToken, 'auth');
  });

  test('a new phone can send to an old receiver', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final key = List<int>.generate(32, (i) => i);
    final payload =
        'toollab-x-pair:${base64Url.encode(utf8.encode(jsonEncode({
          'h': ['127.0.0.1'],
          'p': server.port,
          'k': base64Url.encode(key),
        })))}';
    final received = server.first.then((request) async {
      expect(request.uri.path, '/x-pair');
      final body = await utf8.decodeStream(request);
      final box = SecretBox.fromConcatenation(
        base64.decode(body),
        nonceLength: 12,
        macLength: 16,
      );
      final clear = await AesGcm.with256bits().decrypt(
        box,
        secretKey: SecretKey(key),
      );
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return jsonDecode(utf8.decode(clear));
    });
    expect(await XPairingReceiver.send(payload, _session), isTrue);
    expect(await received, _session.toJson());
  });

  test(
    'an incomplete session is rejected without consuming the code',
    () async {
      final receiver = await _start();
      final payload = _loopbackCode(receiver);
      final data =
          jsonDecode(utf8.decode(base64Url.decode(payload.split(':')[1])))
              as Map<String, dynamic>;
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode({'auth_token': 'auth'})),
        secretKey: SecretKey(base64Url.decode(data['k'] as String)),
      );
      final response = await http.post(
        Uri.parse('http://127.0.0.1:${receiver.port}/x-pair'),
        body: base64.encode(box.concatenation()),
      );
      expect(response.statusCode, HttpStatus.badRequest);
      expect(await XPairingReceiver.send(payload, _session), isTrue);
      expect((await receiver.session).csrfToken, 'csrf');
    },
  );
}
