import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rhttp/rhttp.dart';

class AppHttpClient {
  AppHttpClient._();

  static final Future<void> _initialization = Rhttp.init();
  static final Future<http.Client> _client = _createClient();

  static Future<http.Client> get client => _client;

  static Future<http.Client> _createClient() async {
    await _initialization;
    return RhttpCompatibleClient.create();
  }

  /// Must be created in the isolate that uses it because rhttp's Rust binding
  /// is isolate-local.
  static Future<HttpClient> createIoClient() async {
    await _initialization;
    return IoCompatibleClient.create();
  }

  /// Must be created in the isolate that uses it because rhttp's Rust binding
  /// and connection pool are isolate-local.
  static Future<RhttpClient> createStreamingClient() async {
    await _initialization;
    return RhttpClient.create();
  }
}
