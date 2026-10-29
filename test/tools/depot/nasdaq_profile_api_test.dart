import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tool_lab/services/app_http_client.dart';
import 'package:tool_lab/tools/depot/market_data/nasdaq_profile_api.dart';
import 'package:tool_lab/tools/depot/market_data/yahoo_finance_api.dart';

void main() {
  tearDown(() => AppHttpClient.testClient = null);

  test(
    'uses Nasdaq region for a matching Yahoo equity without a session',
    () async {
      AppHttpClient.testClient = MockClient((request) async {
        if (request.url.host == 'api.nasdaq.com') {
          return http.Response(
            jsonEncode({
              'data': {
                'Symbol': {'value': 'TSM'},
                'Region': {'value': 'Asia'},
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'quotes': [
              {'symbol': 'TSM', 'quoteType': 'EQUITY', 'sector': 'Technology'},
            ],
          }),
          200,
        );
      });
      final result = await YahooFinanceApi.assetProfile('TSM');
      expect(result?.profile.region, 'asia');
      expect(result?.profile.sector, 'Technology');
      expect(result?.profile.country, isNull);
    },
  );

  test('rejects mismatched symbols and unsupported listings', () async {
    var requests = 0;
    AppHttpClient.testClient = MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode({
          'data': {
            'Symbol': {'value': 'OTHER'},
            'Region': {'value': 'Europe'},
          },
        }),
        200,
      );
    });
    expect(await NasdaqProfileApi.region('SAP'), isNull);
    expect(await NasdaqProfileApi.region('SAP.DE'), isNull);
    expect(requests, 1);
  });

  test('does not use stock fallback for ETFs', () async {
    AppHttpClient.testClient = MockClient((request) async {
      expect(request.url.host, isNot('api.nasdaq.com'));
      return http.Response(
        jsonEncode({
          'quotes': [
            {'symbol': 'VTI', 'quoteType': 'ETF'},
          ],
        }),
        200,
      );
    });
    expect(await YahooFinanceApi.assetProfile('VTI'), isNull);
  });
}
