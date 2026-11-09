import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

import 'news_error.dart';

class NewsHttp {
  NewsHttp._();

  // Several news sites serve stripped or blocked pages to unknown clients.
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static Uri parseUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      throw const NewsException(NewsError.invalidUrl);
    }
    return uri;
  }

  /// Returns 2xx and 304 responses; everything else throws [NewsException].
  static Future<http.Response> get(
    Uri uri, {
    required String accept,
    required Duration timeout,
    required int maxBytes,
    Map<String, String> headers = const {},
  }) async {
    final http.Response response;
    try {
      final client = await AppHttpClient.client;
      response = await client
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept': accept,
              'Accept-Language': 'en-US,en;q=0.9,de;q=0.8',
              ...headers,
            },
          )
          .timeout(timeout);
    } catch (e) {
      debugLog('[NewsHttp] $uri unreachable: $e');
      throw const NewsException(NewsError.unreachable);
    }
    if (response.statusCode >= 400) {
      throw NewsException(NewsError.httpStatus, status: response.statusCode);
    }
    if (response.bodyBytes.length > maxBytes) {
      throw const NewsException(NewsError.tooLarge);
    }
    return response;
  }

  static String decodeBody(Uint8List bytes, String? contentType) {
    final charset = RegExp(
      r'charset\s*=\s*"?([\w-]+)',
      caseSensitive: false,
    ).firstMatch(contentType ?? '')?.group(1);
    final encoding = charset == null ? null : Encoding.getByName(charset);
    final body = encoding != null
        ? encoding.decode(bytes)
        : utf8.decode(bytes, allowMalformed: true);
    return body.startsWith('﻿') ? body.substring(1) : body;
  }
}
