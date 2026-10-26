import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'parqet_exception.dart';

class ParqetTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const ParqetTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpiring =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));
}

/// OAuth 2.0 authorization code flow with PKCE against Parqet Connect, as a
/// public client: there is no secret, only the integration's client id.
class ParqetAuth {
  ParqetAuth._();

  static final Uri _authorizeUri = Uri.parse(
    'https://connect.parqet.com/oauth2/authorize',
  );
  static final Uri _tokenUri = Uri.parse(
    'https://connect.parqet.com/oauth2/token',
  );
  static const String scope = 'portfolio:read';

  /// Fixed because the redirect URI must match the one registered with the
  /// integration exactly. A loopback listener works on Android and Windows
  /// alike, without an app link.
  static const int redirectPort = 47615;
  static const String redirectUri = 'http://127.0.0.1:$redirectPort/callback';

  static const _timeout = Duration(seconds: 20);
  static const _loginTimeout = Duration(minutes: 5);

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'depot_parqet_access_token';
  static const _refreshKey = 'depot_parqet_refresh_token';
  static const _expiresKey = 'depot_parqet_expires_at';

  static Future<ParqetTokens?> readTokens() async {
    try {
      final access = await _storage.read(key: _accessKey);
      final refresh = await _storage.read(key: _refreshKey);
      final expires = int.tryParse(await _storage.read(key: _expiresKey) ?? '');
      if (access == null || refresh == null || expires == null) return null;
      return ParqetTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expires),
      );
    } catch (e) {
      errorLog('[ParqetAuth] Reading tokens failed: $e');
      return null;
    }
  }

  static Future<void> _saveTokens(ParqetTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    await _storage.write(
      key: _expiresKey,
      value: '${tokens.expiresAt.millisecondsSinceEpoch}',
    );
  }

  static Future<void> clearTokens() async {
    for (final key in [_accessKey, _refreshKey, _expiresKey]) {
      await _storage.delete(key: key);
    }
  }

  /// Opens the Parqet consent page in the browser and waits for its redirect
  /// on the loopback port. [responseHtml] is what the browser tab shows after.
  static Future<void> login({
    required String clientId,
    required String responseHtml,
  }) async {
    final verifier = _randomUrlSafe(48);
    final state = _randomUrlSafe(16);
    final challenge = base64UrlEncode(
      sha256.convert(ascii.encode(verifier)).bytes,
    ).replaceAll('=', '');

    final HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        redirectPort,
      );
    } on SocketException catch (e) {
      throw ParqetException(ParqetErrorKind.portBusy, '$e');
    }

    try {
      final authorize = _authorizeUri.replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'scope': scope,
          'state': state,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
        },
      );
      if (!await launchUrl(authorize, mode: LaunchMode.externalApplication)) {
        throw const ParqetException(
          ParqetErrorKind.network,
          'Could not open the browser',
        );
      }

      final Uri callback;
      try {
        callback = await _awaitCallback(server, responseHtml);
      } on TimeoutException {
        throw const ParqetException(ParqetErrorKind.timeout);
      }

      final error = callback.queryParameters['error'];
      if (error != null) throw ParqetException(ParqetErrorKind.denied, error);
      if (callback.queryParameters['state'] != state) {
        throw const ParqetException(
          ParqetErrorKind.invalidResponse,
          'State mismatch',
        );
      }
      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const ParqetException(
          ParqetErrorKind.invalidResponse,
          'No authorization code',
        );
      }

      final tokens = await _tokenRequest({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'code_verifier': verifier,
      });
      await _saveTokens(tokens);
    } finally {
      await server.close(force: true);
    }
  }

  static Future<Uri> _awaitCallback(
    HttpServer server,
    String responseHtml,
  ) async {
    await for (final request in server.timeout(_loginTimeout)) {
      // Browsers also ask for /favicon.ico; only the callback path counts.
      if (request.uri.path != '/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(responseHtml);
      await request.response.close();
      return request.uri;
    }
    throw TimeoutException('Login window closed');
  }

  /// A token valid for at least another minute, refreshed when needed.
  static Future<String> accessToken(String clientId) async {
    final tokens = await readTokens();
    if (tokens == null) {
      throw const ParqetException(ParqetErrorKind.notConnected);
    }
    if (!tokens.isExpiring) return tokens.accessToken;

    try {
      final refreshed = await _tokenRequest({
        'grant_type': 'refresh_token',
        'refresh_token': tokens.refreshToken,
        'client_id': clientId,
      }, previousRefreshToken: tokens.refreshToken);
      await _saveTokens(refreshed);
      return refreshed.accessToken;
    } on ParqetException catch (e) {
      // The app and a scheduled run are separate isolates; if the other one
      // just rotated the refresh token, its result is already stored.
      if (e.kind == ParqetErrorKind.unauthorized) {
        final current = await readTokens();
        if (current != null &&
            current.refreshToken != tokens.refreshToken &&
            !current.isExpiring) {
          return current.accessToken;
        }
      }
      rethrow;
    }
  }

  static Future<ParqetTokens> _tokenRequest(
    Map<String, String> body, {
    String? previousRefreshToken,
  }) async {
    final client = await AppHttpClient.client;
    final http.Response res;
    try {
      res = await client
          .post(
            _tokenUri,
            headers: const {'Accept': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
    } catch (e) {
      throw ParqetException(ParqetErrorKind.network, '$e');
    }

    if (res.statusCode == 400 || res.statusCode == 401) {
      throw ParqetException(ParqetErrorKind.unauthorized, res.body);
    }
    if (res.statusCode != 200) {
      throw ParqetException(
        ParqetErrorKind.server,
        'HTTP ${res.statusCode}: ${res.body}',
      );
    }

    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final access = json['access_token'] as String;
      final refresh = json['refresh_token'] as String? ?? previousRefreshToken;
      if (refresh == null) {
        throw const FormatException('No refresh token');
      }
      final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
      return ParqetTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );
    } catch (e) {
      throw ParqetException(ParqetErrorKind.invalidResponse, '$e');
    }
  }

  static String _randomUrlSafe(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
