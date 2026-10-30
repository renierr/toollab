import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_api.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_auth.dart';
import 'package:tool_lab/tools/depot/parqet/parqet_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? previousOverrides;

  setUpAll(() {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _OfflineHttpOverrides();
  });

  tearDownAll(() {
    AppHttpClient.testClient = null;
    HttpOverrides.global = previousOverrides;
  });

  setUp(() async {
    // Anything a test does not mock must fail instead of reaching the network.
    AppHttpClient.testClient = MockClient((request) async {
      throw StateError('Unmocked request: ${request.url}');
    });
    FlutterSecureStorage.setMockInitialValues({});
    await ParqetAuth.clearTokens();
    FlutterSecureStorage.setMockInitialValues({
      'depot_parqet_access_token': 'stale',
      'depot_parqet_refresh_token': 'refresh-1',
      'depot_parqet_expires_at':
          '${DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch}',
    });
  });

  tearDown(() {
    AppHttpClient.testClient = null;
  });

  test('retries a rejected token once with a refreshed one', () async {
    final calls = <String>[];
    AppHttpClient.testClient = MockClient((request) async {
      calls.add('${request.url.path} ${request.headers['Authorization']}');
      if (request.url.path == '/oauth2/token') {
        expect(request.body, contains('refresh_token=refresh-1'));
        return http.Response(
          jsonEncode({
            'access_token': 'fresh',
            'refresh_token': 'refresh-2',
            'expires_in': 3600,
          }),
          200,
        );
      }
      if (request.headers['Authorization'] == 'Bearer stale') {
        return http.Response('{"message":"expired"}', 401);
      }
      return http.Response('{"items":[]}', 200);
    });

    final portfolios = await const ParqetApi(
      clientId: 'test-client',
    ).portfolios();

    expect(portfolios, isEmpty);
    expect(calls, [
      '/portfolios Bearer stale',
      '/oauth2/token null',
      '/portfolios Bearer fresh',
    ]);
    expect((await ParqetAuth.readTokens())?.refreshToken, 'refresh-2');
  });

  test('does not loop on a rejected grant', () async {
    final calls = <String>[];
    AppHttpClient.testClient = MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path == '/oauth2/token') {
        return http.Response('{"message":"invalid_grant"}', 400);
      }
      return http.Response('{}', 401);
    });

    await expectLater(
      const ParqetApi(clientId: 'test-client').portfolios(),
      throwsA(
        isA<ParqetException>().having(
          (e) => e.kind,
          'kind',
          ParqetErrorKind.unauthorized,
        ),
      ),
    );
    expect(calls, ['/portfolios', '/oauth2/token']);
  });

  for (final (status, body, kind) in [
    (
      400,
      '{"message":"client_not_found","error":"Bad Request"}',
      ParqetErrorKind.server,
    ),
    (429, '{}', ParqetErrorKind.rateLimited),
    (500, '{}', ParqetErrorKind.server),
  ]) {
    test('reports a $status token response as ${kind.name}', () async {
      AppHttpClient.testClient = MockClient((request) async {
        if (request.url.path == '/oauth2/token') {
          return http.Response(body, status);
        }
        return http.Response('{}', 401);
      });

      await expectLater(
        const ParqetApi(clientId: 'test-client').portfolios(),
        throwsA(isA<ParqetException>().having((e) => e.kind, 'kind', kind)),
      );
    });
  }
}

class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Unexpected dart:io HttpClient in parqet auth test');
}
