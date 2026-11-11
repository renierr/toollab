import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/helpers/lan_pairing.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_auth.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_exception.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_pairing.dart';

void main() {
  test('a code carries the public challenge, not a client id', () async {
    final receiver = await PairingReceiver.start(
      protocol: ParqetPairing.protocol,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    addTearDown(receiver.close);

    final request = ParqetAuth.beginLogin(clientId: 'client');
    final code = PairingCode.parse(
      receiver.payload(ParqetPairing.fields(request)),
      protocol: ParqetPairing.protocol,
    );
    final read = ParqetPairing.read(code);

    expect(code.fields.containsKey('c'), isFalse);
    expect(read.state, request.state);
    expect(read.challenge, request.challenge);
    expect(read.state, isNot(request.challenge));
  });

  test('a redirect for another state is rejected', () async {
    final request = ParqetAuth.beginLogin(clientId: 'client');
    expect(
      () => request.complete(
        Uri.parse('${ParqetAuth.redirectUri}?state=other&code=code'),
      ),
      throwsA(
        isA<ParqetException>().having(
          (e) => e.kind,
          'kind',
          ParqetErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('the authorize URL uses the challenge, never the verifier', () {
    final request = ParqetAuth.beginLogin(clientId: 'client');
    final query = request.authorizeUri.queryParameters;
    expect(query['client_id'], 'client');
    expect(query['state'], request.state);
    expect(query['code_challenge'], request.challenge);
    expect(query['code_challenge_method'], 'S256');
    expect(query['redirect_uri'], ParqetAuth.redirectUri);
  });

  test(
    'the phone client ID and redirect are exchanged using the TV verifier',
    () async {
      final request = ParqetAuth.beginLogin(clientId: '');
      AppHttpClient.testClient = MockClient((httpRequest) async {
        expect(httpRequest.url.host, 'connect.parqet.com');
        final fields = Uri.splitQueryString(httpRequest.body);
        expect(fields['client_id'], 'phone-client');
        expect(fields['code'], 'authorization-code');
        expect(fields['redirect_uri'], ParqetAuth.redirectUri);
        final challenge = base64UrlEncode(
          sha256.convert(ascii.encode(fields['code_verifier']!)).bytes,
        ).replaceAll('=', '');
        expect(challenge, request.challenge);
        return http.Response(
          jsonEncode({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
          }),
          200,
        );
      });
      addTearDown(() => AppHttpClient.testClient = null);
      final result = await ParqetPairing.complete(request, {
        'c': 'phone-client',
        'u':
            '${ParqetAuth.redirectUri}?state=${request.state}&code=authorization-code',
      });
      expect(result.clientId, 'phone-client');
      expect(result.tokens.refreshToken, 'refresh');
    },
  );

  test('rejects a redirect to a different origin', () async {
    final request = ParqetAuth.beginLogin(clientId: 'client');
    await expectLater(
      request.complete(
        Uri.parse(
          'https://example.com/callback?state=${request.state}&code=code',
        ),
      ),
      throwsA(
        isA<ParqetException>().having(
          (e) => e.kind,
          'kind',
          ParqetErrorKind.invalidResponse,
        ),
      ),
    );
  });
}
