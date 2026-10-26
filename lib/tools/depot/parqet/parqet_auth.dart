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

  /// Granted scopes, when the token response names them.
  final String? scope;

  const ParqetTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.scope,
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
  static const String writeScope = 'portfolio:write';
  static const String scope = 'portfolio:read $writeScope';

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
  static const _scopeKey = 'depot_parqet_scope';

  /// In-memory copy of the stored grant. Secure storage is the cross-isolate
  /// source of truth; this only spares a keystore read per request.
  static ParqetTokens? _cached;

  /// Shared by concurrent callers, so a parallel sync refreshes once instead
  /// of rotating the refresh token per request.
  static Future<String>? _pendingAccessToken;

  /// Scopes Parqet granted, as named in the last token response. Empty when
  /// the response named none, so callers must not read it as "no write".
  static Future<Set<String>> grantedScopes() async {
    try {
      final granted = await _storage.read(key: _scopeKey) ?? '';
      return granted
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (e) {
      errorLog('[ParqetAuth] Reading scope failed: $e');
      return const {};
    }
  }

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
        scope: await _storage.read(key: _scopeKey),
      );
    } catch (e) {
      errorLog('[ParqetAuth] Reading tokens failed: $e');
      return null;
    }
  }

  static Future<void> _saveTokens(ParqetTokens tokens) async {
    _cached = tokens;
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    await _storage.write(
      key: _expiresKey,
      value: '${tokens.expiresAt.millisecondsSinceEpoch}',
    );
    final scope = tokens.scope;
    if (scope != null) await _storage.write(key: _scopeKey, value: scope);
  }

  static Future<void> clearTokens() async {
    _cached = null;
    for (final key in [_accessKey, _refreshKey, _expiresKey, _scopeKey]) {
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
      if (error == 'invalid_scope') {
        throw const ParqetException(
          ParqetErrorKind.scopeNotAllowed,
          'invalid_scope',
        );
      }
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
      // A login that does not name its scopes leaves the stored grant
      // unknown rather than showing the scopes that were merely requested.
      if (tokens.scope == null) await _storage.delete(key: _scopeKey);
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
  static Future<String> accessToken(String clientId) {
    final pending = _pendingAccessToken;
    if (pending != null) return pending;
    final request = _accessToken(clientId);
    return _pendingAccessToken = request.whenComplete(
      () => _pendingAccessToken = null,
    );
  }

  static Future<String> _accessToken(String clientId) async {
    final cached = _cached;
    if (cached != null && !cached.isExpiring) return cached.accessToken;

    final tokens = await readTokens();
    if (tokens == null) {
      throw const ParqetException(ParqetErrorKind.notConnected);
    }
    if (!tokens.isExpiring) {
      _cached = tokens;
      return tokens.accessToken;
    }

    try {
      final refreshed = await _tokenRequest({
        'grant_type': 'refresh_token',
        'refresh_token': tokens.refreshToken,
        'client_id': clientId,
      }, previousRefreshToken: tokens.refreshToken);
      final merged = ParqetTokens(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken,
        expiresAt: refreshed.expiresAt,
        // A refresh cannot widen the grant, so keep what is known.
        scope: refreshed.scope ?? tokens.scope,
      );
      await _saveTokens(merged);
      return merged.accessToken;
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
        scope: json['scope'] as String?,
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
