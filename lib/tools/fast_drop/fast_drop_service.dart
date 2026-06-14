import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:rhttp/rhttp.dart';
import 'fast_drop_model.dart';

class FastDropService {
  static RhttpClient? _client;

  static Future<RhttpClient> get _clientFuture async {
    _client ??= await RhttpClient.create();
    return _client!;
  }

  static Duration _adaptiveTimeout({
    required int bytes,
    int baseSeconds = 10,
    int maxSeconds = 600,
    double bytesPerSecond = 100 * 1024,
  }) {
    final estimatedSeconds = (bytes / bytesPerSecond).ceil();
    final total = baseSeconds + estimatedSeconds;
    return Duration(seconds: total.clamp(0, maxSeconds));
  }

  static String _sanitizeUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  static Future<List<FastDropItem>> fetchDrops(String baseUrl) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop';
    final response = await client.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final List<dynamic> list = data['drops'] ?? [];
        return list.map((item) => FastDropItem.fromJson(item)).toList();
      } else {
        throw Exception(data['error'] ?? 'Server error fetching drops');
      }
    } else {
      throw Exception('Server returned status code ${response.statusCode}');
    }
  }

  static Future<void> uploadDrop({
    required String baseUrl,
    required String filename,
    required Uint8List bytes,
    required String retention,
    required String source,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop';
    final total = bytes.length;
    const chunkSize = 1024 * 1024;
    final cancelToken = CancelToken();

    try {
      if (isCancelled != null && isCancelled()) {
        throw Exception('Upload cancelled by user');
      }

      final timeout = _adaptiveTimeout(
        bytes: total,
        baseSeconds: 30,
        bytesPerSecond: 100 * 1024,
      );

      final response = await client
          .requestText(
            method: HttpMethod.post,
            url: url,
            headers: HttpHeaders.rawMap({
              'X-Filename': Uri.encodeComponent(filename),
              'X-Retention': retention,
              'X-Source': source,
              'Content-Type': mimeType.isEmpty
                  ? 'application/octet-stream'
                  : mimeType,
            }),
            body: HttpBody.stream(
              _chunkedByteStream(
                bytes,
                chunkSize: chunkSize,
                isCancelled: isCancelled,
              ),
              length: total,
            ),
            cancelToken: cancelToken,
            onSendProgress: (sent, progressTotal) {
              if (isCancelled != null && isCancelled()) {
                unawaited(cancelToken.cancel());
              }
              onProgress?.call(sent, progressTotal > 0 ? progressTotal : total);
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ?? 'Failed to upload drop: ${response.statusCode}',
        );
      }
    } on RhttpCancelException {
      throw Exception('Upload cancelled by user');
    }
  }

  static Stream<List<int>> _chunkedByteStream(
    Uint8List bytes, {
    required int chunkSize,
    bool Function()? isCancelled,
  }) async* {
    final total = bytes.length;
    for (int i = 0; i < total; i += chunkSize) {
      if (isCancelled != null && isCancelled()) {
        throw Exception('Upload cancelled by user');
      }
      final end = (i + chunkSize).clamp(0, total);
      yield Uint8List.sublistView(bytes, i, end);
    }
  }

  static Future<void> deleteDrop(String baseUrl, String id) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final response = await client
        .delete(url)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to delete drop: ${response.statusCode}',
      );
    }
  }

  static Future<void> updateDescription(
    String baseUrl,
    String id,
    String description,
  ) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/description';
    final response = await client
        .patch(url, body: HttpBody.json({'description': description}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to update description: ${response.statusCode}',
      );
    }
  }

  static Future<void> updateRetention(
    String baseUrl,
    String id,
    String retention,
  ) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/retention';
    final response = await client
        .patch(url, body: HttpBody.json({'retention': retention}))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to update retention: ${response.statusCode}',
      );
    }
  }

  static Future<void> keepDrop(String baseUrl, String id) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/keep';
    final response = await client
        .patch(url)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to update drop: ${response.statusCode}',
      );
    }
  }

  static Future<Uint8List> downloadDrop({
    required String baseUrl,
    required String id,
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final cancelToken = CancelToken();

    try {
      if (isCancelled != null && isCancelled()) {
        throw Exception('Download cancelled by user');
      }

      final response = await client.requestBytes(
        method: HttpMethod.get,
        url: url,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (isCancelled != null && isCancelled()) {
            unawaited(cancelToken.cancel());
          }
          onProgress?.call(received, total);
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download drop: ${response.statusCode}');
      }
      return response.body;
    } on RhttpCancelException {
      throw Exception('Download cancelled by user');
    }
  }

  static Future<String> downloadDropToFile({
    required String baseUrl,
    required String id,
    required String outputPath,
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final cancelToken = CancelToken();
    final file = File(outputPath);
    await file.parent.create(recursive: true);

    final sink = file.openWrite();
    try {
      if (isCancelled != null && isCancelled()) {
        throw Exception('Download cancelled by user');
      }

      final streamedResponse = await client.requestStream(
        method: HttpMethod.get,
        url: url,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (isCancelled != null && isCancelled()) {
            unawaited(cancelToken.cancel());
          }
          onProgress?.call(received, total);
        },
      );

      if (streamedResponse.statusCode != 200) {
        final errorBody = await _readStreamBody(streamedResponse.body);
        final parsedError = _parseError(errorBody);
        throw Exception(
          parsedError ??
              'Failed to download drop: ${streamedResponse.statusCode}',
        );
      }

      await for (final chunk in streamedResponse.body) {
        if (isCancelled != null && isCancelled()) {
          unawaited(cancelToken.cancel());
          throw Exception('Download cancelled by user');
        }
        sink.add(chunk);
      }

      await sink.flush();
      await sink.close();
      return outputPath;
    } on RhttpCancelException {
      await sink.close();
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      throw Exception('Download cancelled by user');
    } catch (_) {
      await sink.close();
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<String> _readStreamBody(Stream<Uint8List> stream) async {
    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytesBuilder.add(chunk);
    }
    return utf8.decode(bytesBuilder.takeBytes(), allowMalformed: true);
  }

  static String? _parseError(String body) {
    if (body.isEmpty) return null;
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic> && json['error'] is String) {
        return json['error'] as String;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
