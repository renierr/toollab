import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/app_http_client.dart';

enum WeatherError { unreachable, notFound, httpStatus, invalidData }

class WeatherException implements Exception {
  const WeatherException(this.error, {this.status});

  final WeatherError error;
  final int? status;

  @override
  String toString() =>
      'WeatherException($error${status == null ? '' : ', $status'})';
}

class WeatherHttp {
  WeatherHttp._();

  static const String userAgent = 'ToolLab-Weather/1.0';
  static const Duration _timeout = Duration(seconds: 20);
  static const int _maxBytes = 8 * 1024 * 1024;

  static Future<Uint8List> getBytes(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: abort.future,
    )..headers.addAll({'User-Agent': userAgent, ...headers});
    try {
      return await _send(request).timeout(_timeout);
    } on TimeoutException {
      debugLog('[WeatherHttp] $uri timed out');
      throw const WeatherException(WeatherError.unreachable);
    } finally {
      if (!abort.isCompleted) abort.complete();
    }
  }

  static Future<Uint8List> _send(http.BaseRequest request) async {
    final http.StreamedResponse response;
    try {
      response = await (await AppHttpClient.client).send(request);
    } catch (e) {
      debugLog('[WeatherHttp] ${request.url} unreachable: $e');
      throw const WeatherException(WeatherError.unreachable);
    }
    if (response.statusCode == 404) {
      throw const WeatherException(WeatherError.notFound);
    }
    if (response.statusCode >= 400) {
      throw WeatherException(
        WeatherError.httpStatus,
        status: response.statusCode,
      );
    }
    final body = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.stream) {
        body.add(chunk);
        if (body.length > _maxBytes) {
          throw const WeatherException(WeatherError.invalidData);
        }
      }
    } on WeatherException {
      rethrow;
    } catch (e) {
      debugLog('[WeatherHttp] ${request.url} download failed: $e');
      throw const WeatherException(WeatherError.unreachable);
    }
    return body.takeBytes();
  }
}
