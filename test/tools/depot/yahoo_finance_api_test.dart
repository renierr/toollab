import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/tools/depot/market_data/yahoo_finance_api.dart';

void main() {
  tearDown(() => AppHttpClient.testClient = null);

  const listings = '''
  {"quotes":[{"symbol":"SPCX","longname":"SpaceX","quoteType":"EQUITY",
    "exchange":"NMS","exchDisp":"NASDAQ"}]}
  ''';

  test('retries a throttled request on the other query host', () async {
    final hosts = <String>[];
    AppHttpClient.testClient = MockClient((request) async {
      hosts.add(request.url.host);
      return hosts.length == 1
          ? http.Response('slow down', 429)
          : http.Response(listings, 200);
    });
    final results = await YahooFinanceApi.searchListings('US84615Q1031');
    expect(hosts, ['query2.finance.yahoo.com', 'query1.finance.yahoo.com']);
    expect(results.single.symbol, 'SPCX');
  });

  test('retries a failed connection on the other query host', () async {
    final hosts = <String>[];
    AppHttpClient.testClient = MockClient((request) async {
      hosts.add(request.url.host);
      if (hosts.length == 1) throw const SocketExceptionStub();
      return http.Response(listings, 200);
    });
    final results = await YahooFinanceApi.searchListings('US84615Q1031');
    expect(hosts, hasLength(2));
    expect(results.single.symbol, 'SPCX');
  });

  test('retries a forbidden or malformed response on the other host', () async {
    for (final response in [
      http.Response('forbidden', 403),
      http.Response('<html>unavailable</html>', 200),
    ]) {
      var calls = 0;
      AppHttpClient.testClient = MockClient((_) async {
        return ++calls == 1 ? response : http.Response(listings, 200);
      });
      final results = await YahooFinanceApi.searchListings('US84615Q1031');
      expect(calls, 2);
      expect(results.single.symbol, 'SPCX');
    }
  });

  test('a not-found response does not retry', () async {
    var calls = 0;
    AppHttpClient.testClient = MockClient((_) async {
      calls++;
      return http.Response('not found', 404);
    });
    await expectLater(
      YahooFinanceApi.searchListings('NOPE'),
      throwsA(isA<YahooFinanceException>()),
    );
    expect(calls, 1);
  });
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'connection refused';
}
