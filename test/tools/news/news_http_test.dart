import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/tools/news/news_error.dart';
import 'package:tool_lab/tools/news/news_http.dart';

Matcher _throwsNews(NewsError error) =>
    throwsA(isA<NewsException>().having((e) => e.error, 'error', error));

void main() {
  final uri = Uri.parse('https://example.test/feed');
  tearDown(() => AppHttpClient.testClient = null);

  test('stops reading once the body passes the size limit', () async {
    var chunks = 0;
    AppHttpClient.testClient = MockClient.streaming(
      (request, body) async => http.StreamedResponse(
        Stream.periodic(Duration.zero, (_) {
          chunks++;
          return List.filled(1024, 65);
        }).take(100),
        200,
      ),
    );
    await expectLater(
      NewsHttp.get(
        uri,
        accept: '*/*',
        timeout: const Duration(seconds: 5),
        maxBytes: 4096,
      ),
      _throwsNews(NewsError.tooLarge),
    );
    expect(chunks, lessThan(10));
  });

  test('rejects a declared length above the limit before reading', () async {
    AppHttpClient.testClient = MockClient.streaming(
      (request, body) async => http.StreamedResponse(
        const Stream.empty(),
        200,
        contentLength: 10000,
      ),
    );
    await expectLater(
      NewsHttp.get(
        uri,
        accept: '*/*',
        timeout: const Duration(seconds: 5),
        maxBytes: 4096,
      ),
      _throwsNews(NewsError.tooLarge),
    );
  });

  test('times out a stalled download and aborts the request', () async {
    final stalled = StreamController<List<int>>();
    addTearDown(stalled.close);
    http.BaseRequest? sent;
    AppHttpClient.testClient = MockClient.streaming((request, body) async {
      sent = request;
      stalled.add([65]);
      return http.StreamedResponse(stalled.stream, 200);
    });
    await expectLater(
      NewsHttp.get(
        uri,
        accept: '*/*',
        timeout: const Duration(milliseconds: 50),
        maxBytes: 4096,
      ),
      _throwsNews(NewsError.unreachable),
    );
    final trigger = (sent! as http.Abortable).abortTrigger!;
    await expectLater(trigger, completes);
  });
}
