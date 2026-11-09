import 'dart:async';
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
  /// [timeout] covers the whole download, and a timeout or an oversized body
  /// aborts the request instead of letting it run on in the background.
  static Future<http.Response> get(
    Uri uri, {
    required String accept,
    required Duration timeout,
    required int maxBytes,
    Map<String, String> headers = const {},
  }) {
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    final request =
        http.AbortableRequest('GET', uri, abortTrigger: abort.future)
          ..headers.addAll({
            'User-Agent': _userAgent,
            'Accept': accept,
            'Accept-Language': 'en-US,en;q=0.9,de;q=0.8',
            ...headers,
          });
    return _download(request, maxBytes, cancel).timeout(
      timeout,
      onTimeout: () {
        cancel();
        debugLog('[NewsHttp] $uri timed out');
        throw const NewsException(NewsError.unreachable);
      },
    );
  }

  static Future<http.Response> _download(
    http.BaseRequest request,
    int maxBytes,
    void Function() cancel,
  ) async {
    final http.StreamedResponse response;
    try {
      response = await (await AppHttpClient.client).send(request);
    } catch (e) {
      debugLog('[NewsHttp] ${request.url} unreachable: $e');
      throw const NewsException(NewsError.unreachable);
    }
    if (response.statusCode >= 400) {
      cancel();
      throw NewsException(NewsError.httpStatus, status: response.statusCode);
    }
    if ((response.contentLength ?? 0) > maxBytes) {
      cancel();
      throw const NewsException(NewsError.tooLarge);
    }
    final body = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.stream) {
        body.add(chunk);
        if (body.length > maxBytes) {
          cancel();
          throw const NewsException(NewsError.tooLarge);
        }
      }
    } on NewsException {
      rethrow;
    } catch (e) {
      debugLog('[NewsHttp] ${request.url} download failed: $e');
      throw const NewsException(NewsError.unreachable);
    }
    return http.Response.bytes(
      body.takeBytes(),
      response.statusCode,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      reasonPhrase: response.reasonPhrase,
    );
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
