import 'dart:convert';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

class NasdaqProfileApi {
  NasdaqProfileApi._();

  static Future<String?> region(String symbol) async {
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(symbol)) return null;
    try {
      final client = await AppHttpClient.client;
      final response = await client
          .get(
            Uri.https('api.nasdaq.com', '/api/company/$symbol/company-profile'),
            headers: const {
              'User-Agent': 'Mozilla/5.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final data = json is Map ? json['data'] : null;
      if (data is! Map) return null;
      final reportedSymbol = (data['Symbol'] as Map?)?['value'];
      if (reportedSymbol is! String ||
          reportedSymbol.toUpperCase() != symbol.toUpperCase()) {
        return null;
      }
      final region = (data['Region'] as Map?)?['value'];
      return switch (region) {
        'North America' => 'northAmerica',
        'South America' => 'southAmerica',
        'Europe' => 'europe',
        'Asia' => 'asia',
        'Oceania' => 'oceania',
        'Africa' => 'africa',
        _ => null,
      };
    } catch (e) {
      debugLog('[NasdaqProfileApi] Region unavailable for $symbol: $e');
      return null;
    }
  }
}
