import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import 'deepseek_history.dart';
import 'deepseek_pow.dart';
import 'deepseek_stream.dart';

enum DeepSeekErrorKind { unauthorized, banned, challenge, network, server }

class DeepSeekException implements Exception {
  final DeepSeekErrorKind kind;
  final String? message;

  const DeepSeekException(this.kind, [this.message]);

  @override
  String toString() =>
      'DeepSeekException($kind${message == null ? '' : ': $message'})';
}

/// The private API chat.deepseek.com's own web app talks to, authenticated
/// with the account's `userToken`.
class DeepSeekApi {
  final String token;
  final String locale;

  DeepSeekApi(this.token, {this.locale = 'en'});

  static final Uri _base = Uri.parse('https://chat.deepseek.com');
  static const String _completionPath = '/api/v0/chat/completion';
  static const Duration _timeout = Duration(seconds: 30);
  static const String _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36';

  /// The token from the web app's `userToken` local storage entry, which
  /// holds either the bare token or `{"value": token, ...}`.
  static String? tokenFromStorage(Object? raw) {
    var value = raw is String ? raw.trim() : raw;
    // The WebView may hand back the JSON string itself, encoded once more.
    for (var i = 0; i < 2 && value is String; i++) {
      final text = value.trim();
      if (!text.startsWith('{') && !text.startsWith('"')) break;
      try {
        value = jsonDecode(text);
      } on FormatException {
        break;
      }
    }
    if (value is Map) value = value['value'];
    if (value is! String) return null;
    var token = value.trim();
    if (token.startsWith('Bearer ')) token = token.substring(7).trim();
    return token.isEmpty || token == 'null' ? null : token;
  }

  Map<String, String> get _headers => {
    'authorization': 'Bearer $token',
    'content-type': 'application/json',
    'accept': '*/*',
    'origin': _base.toString(),
    'referer': '$_base/',
    'user-agent': _userAgent,
    'x-client-platform': 'web',
    'x-client-version': '2.8.0',
    'x-client-bundle-id': 'com.deepseek.chat',
    'x-client-locale': locale,
    'x-client-timezone-offset': '${DateTime.now().timeZoneOffset.inSeconds}',
  };

  /// The signed-in account's display name, e-mail or phone.
  Future<String?> currentUser() async {
    final data = await _call('GET', '/api/v0/users/current');
    if (data is! Map) return null;
    for (final key in ['email', 'mobile_number', 'id_profile']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is Map && value['name'] is String) return value['name'];
    }
    return null;
  }

  Future<String> createSession() async {
    final data = await _call('POST', '/api/v0/chat_session/create', {});
    final session = data is Map ? (data['chat_session'] ?? data) : null;
    final id = session is Map ? session['id'] : null;
    if (id is! String) {
      throw const DeepSeekException(DeepSeekErrorKind.server, 'no session');
    }
    return id;
  }

  /// The account's conversations, newest first.
  Future<List<DeepSeekRemoteSession>> fetchSessions({int count = 100}) async {
    final data = await _call(
      'GET',
      '/api/v0/chat_session/fetch_page?count=$count',
    );
    final sessions = data is Map ? data['chat_sessions'] : null;
    if (sessions is! List) return const [];
    return [
      for (final item in sessions)
        if (item is Map<String, dynamic>) ?DeepSeekRemoteSession.fromJson(item),
    ];
  }

  Future<DeepSeekHistory> history(String sessionId) async {
    final data = await _call(
      'GET',
      '/api/v0/chat/history_messages'
          '?chat_session_id=${Uri.encodeQueryComponent(sessionId)}',
    );
    if (data is! Map<String, dynamic>) {
      throw const DeepSeekException(DeepSeekErrorKind.server, 'no history');
    }
    return DeepSeekHistory.fromJson(data);
  }

  Future<void> deleteSession(String sessionId) async {
    await _call('POST', '/api/v0/chat_session/delete', {
      'chat_session_ids': [sessionId],
    });
  }

  /// Streams the reply to [prompt] in session [sessionId]; [parentMessageId]
  /// is the previous reply's id, null for the first message.
  Stream<DeepSeekReply> complete({
    required String sessionId,
    required int? parentMessageId,
    required String prompt,
    required bool thinking,
    required bool search,
  }) async* {
    final challenge = await _challenge(_completionPath);
    final answer = await DeepSeekPow.solveInBackground(challenge);
    if (answer == null) {
      throw const DeepSeekException(DeepSeekErrorKind.challenge);
    }
    final request = http.Request('POST', _base.resolve(_completionPath))
      ..headers.addAll(_headers)
      ..headers['x-ds-pow-response'] = challenge.header(answer)
      ..body = jsonEncode({
        'chat_session_id': sessionId,
        'parent_message_id': parentMessageId,
        'model_type': null,
        'prompt': prompt,
        'ref_file_ids': <String>[],
        'thinking_enabled': thinking,
        'search_enabled': search,
        'action': null,
        'preempt': false,
      });
    final client = await AppHttpClient.client;
    final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(_timeout);
    } on DeepSeekException {
      rethrow;
    } catch (e) {
      throw DeepSeekException(DeepSeekErrorKind.network, '$e');
    }
    _checkStatus(response.statusCode);
    final type = response.headers['content-type'] ?? '';
    if (!type.contains('event-stream')) {
      final body = await response.stream.bytesToString();
      _unwrap(body);
      throw DeepSeekException(DeepSeekErrorKind.server, body);
    }
    final parser = DeepSeekStreamParser();
    try {
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (parser.addLine(line)) yield parser.reply;
      }
    } on DeepSeekException {
      rethrow;
    } catch (e) {
      throw DeepSeekException(DeepSeekErrorKind.network, '$e');
    }
    yield parser.reply;
  }

  Future<DeepSeekPowChallenge> _challenge(String targetPath) async {
    final data = await _call('POST', '/api/v0/chat/create_pow_challenge', {
      'target_path': targetPath,
    });
    final challenge = data is Map ? data['challenge'] : null;
    if (challenge is! Map<String, dynamic>) {
      throw const DeepSeekException(DeepSeekErrorKind.challenge);
    }
    return DeepSeekPowChallenge.fromJson(challenge);
  }

  Future<Object?> _call(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final client = await AppHttpClient.client;
    final request = http.Request(method, _base.resolve(path))
      ..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(request).timeout(_timeout),
      );
    } catch (e) {
      throw DeepSeekException(DeepSeekErrorKind.network, '$e');
    }
    _checkStatus(response.statusCode);
    return _unwrap(utf8.decode(response.bodyBytes));
  }

  static void _checkStatus(int status) {
    if (status == 401 || status == 403) {
      throw DeepSeekException(DeepSeekErrorKind.unauthorized, 'HTTP $status');
    }
    if (status >= 400) {
      throw DeepSeekException(DeepSeekErrorKind.server, 'HTTP $status');
    }
  }

  /// Returns `data.biz_data`, throwing for an error `code` or `biz_code`.
  static Object? _unwrap(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw DeepSeekException(DeepSeekErrorKind.server, body);
    }
    if (json is! Map) throw DeepSeekException(DeepSeekErrorKind.server, body);
    final code = (json['code'] as num?)?.toInt() ?? 0;
    final data = json['data'];
    final bizCode = data is Map ? (data['biz_code'] as num?)?.toInt() ?? 0 : 0;
    final failed = code != 0 ? code : bizCode;
    if (failed != 0) {
      final message =
          (data is Map ? data['biz_msg'] : null) ?? json['msg'] ?? '$failed';
      debugLog('[DeepSeekApi] Error $failed: $message');
      throw DeepSeekException(_kindFor(failed), '$message');
    }
    return data is Map ? data['biz_data'] : null;
  }

  static DeepSeekErrorKind _kindFor(int code) => switch (code) {
    40002 || 40003 => DeepSeekErrorKind.unauthorized,
    40012 => DeepSeekErrorKind.banned,
    40300 || 40301 || 40303 || 40304 => DeepSeekErrorKind.challenge,
    _ => DeepSeekErrorKind.server,
  };
}
