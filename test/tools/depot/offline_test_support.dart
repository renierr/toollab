import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:tool_lab/services/app_http_client.dart';

void blockDepotNetwork() {
  final attempts = <String>[];
  late MockClient client;
  HttpOverrides? previous;

  setUpAll(() {
    client = MockClient((request) async {
      attempts.add(request.url.toString());
      throw StateError('Unexpected HTTP request in depot test');
    });
    AppHttpClient.testClient = client;
    previous = HttpOverrides.current;
    HttpOverrides.global = _OfflineHttpOverrides(attempts);
  });
  tearDown(() {
    final actual = List<String>.of(attempts);
    attempts.clear();
    expect(actual, isEmpty, reason: 'Depot tests must not use the network');
  });
  tearDownAll(() {
    AppHttpClient.testClient = null;
    HttpOverrides.global = previous;
    client.close();
  });
}

class _OfflineHttpOverrides extends HttpOverrides {
  final List<String> attempts;

  _OfflineHttpOverrides(this.attempts);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts.add('dart:io HttpClient');
    throw StateError('Unexpected HttpClient in depot test');
  }
}
