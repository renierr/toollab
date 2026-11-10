import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tool_lab/helpers/debug_log.dart';

/// The two cookies x.com's web app authenticates with: `auth_token` is the
/// session itself, `ct0` the CSRF token every request must echo.
class XSession {
  final String authToken;
  final String csrfToken;

  const XSession({required this.authToken, required this.csrfToken});

  static const String authCookie = 'auth_token';
  static const String csrfCookie = 'ct0';

  static XSession? fromCookies(Map<String, String> cookies) {
    final auth = cookies[authCookie]?.trim();
    final csrf = cookies[csrfCookie]?.trim();
    if (auth == null || auth.isEmpty || csrf == null || csrf.isEmpty) {
      return null;
    }
    return XSession(authToken: auth, csrfToken: csrf);
  }

  XSession withCsrf(String csrf) =>
      XSession(authToken: authToken, csrfToken: csrf);

  String get cookieHeader => '$authCookie=$authToken; $csrfCookie=$csrfToken';

  Map<String, String> toJson() => {
    authCookie: authToken,
    csrfCookie: csrfToken,
  };
}

class XSessionStore {
  XSessionStore._();

  static const _storage = FlutterSecureStorage();
  static const _authKey = 'x_feed_auth_token';
  static const _csrfKey = 'x_feed_ct0';
  static const _handleKey = 'x_feed_screen_name';

  static Future<XSession?> read() async {
    try {
      return XSession.fromCookies({
        XSession.authCookie: await _storage.read(key: _authKey) ?? '',
        XSession.csrfCookie: await _storage.read(key: _csrfKey) ?? '',
      });
    } catch (e) {
      errorLog('[XSessionStore] Reading session failed: $e');
      return null;
    }
  }

  static Future<void> save(XSession session) async {
    await _storage.write(key: _authKey, value: session.authToken);
    await _storage.write(key: _csrfKey, value: session.csrfToken);
  }

  static Future<String?> readScreenName() async {
    try {
      return await _storage.read(key: _handleKey);
    } catch (e) {
      errorLog('[XSessionStore] Reading handle failed: $e');
      return null;
    }
  }

  static Future<void> saveScreenName(String screenName) =>
      _storage.write(key: _handleKey, value: screenName);

  static Future<void> clear() async {
    for (final key in [_authKey, _csrfKey, _handleKey]) {
      await _storage.delete(key: key);
    }
  }
}
