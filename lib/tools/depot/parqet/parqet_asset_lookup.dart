import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tool_lab/services/app_http_client.dart';

class ParqetAssetLookup {
  final http.Client? client;

  const ParqetAssetLookup({this.client});

  Future<Set<String>> symbolsForIsin(String isin) async {
    final response = await (client ?? await AppHttpClient.client)
        .get(Uri.https('api.parqet.com', '/v1/assets/$isin'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return {};
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map) return {};
    final asset = json['asset'];
    final security = asset is Map ? asset['security'] : null;
    if (security is! Map || security['isin'] != isin) return {};
    final symbols = security['symbols'];
    if (symbols is! List) return {};
    return {
      for (final entry in symbols)
        if (entry is Map && entry['symbol'] is String)
          (entry['symbol'] as String).toUpperCase(),
    };
  }
}
