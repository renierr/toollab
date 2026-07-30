import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'fast_drop_model.dart';

class FastDropService {
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
    final url = '${_sanitizeUrl(baseUrl)}/api/drop';
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
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
    required String filePath,
    required String retention,
    required String source,
    required String mimeType,
    void Function(int sent, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final url = '${_sanitizeUrl(baseUrl)}/api/drop';
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }
    final total = await file.length();

    if (isCancelled != null && isCancelled()) {
      throw Exception('Upload cancelled by user');
    }

    final timeout = _adaptiveTimeout(
      bytes: total,
      baseSeconds: 30,
      bytesPerSecond: 100 * 1024,
    );

    final httpClient = HttpClient();
    httpClient.connectionTimeout = timeout;

    try {
      final request = await httpClient.postUrl(Uri.parse(url));

      // Set headers
      request.headers.add('X-Filename', Uri.encodeComponent(filename));
      request.headers.add('X-Retention', retention);
      request.headers.add('X-Source', source);
      request.headers.add(
        'Content-Type',
        mimeType.isEmpty ? 'application/octet-stream' : mimeType,
      );
      request.contentLength = total;

      int sent = 0;
      final fileStream = file.openRead().map((chunk) {
        if (isCancelled != null && isCancelled()) {
          throw Exception('Upload cancelled by user');
        }
        sent += chunk.length;
        onProgress?.call(sent, total);
        return chunk;
      });

      try {
        await request.addStream(fileStream);
      } catch (e) {
        request.abort();
        rethrow;
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        final errorData = jsonDecode(responseBody);
        throw Exception(
          errorData['error'] ?? 'Failed to upload drop: ${response.statusCode}',
        );
      }
    } finally {
      httpClient.close();
    }
  }

  static Future<void> deleteDrop(String baseUrl, String id) async {
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final response = await http
        .delete(Uri.parse(url))
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
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/description';
    final response = await http
        .patch(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'description': description}),
        )
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
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/retention';
    final response = await http
        .patch(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'retention': retention}),
        )
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
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/keep';
    final response = await http
        .patch(Uri.parse(url))
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
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final httpClient = HttpClient();

    try {
      if (isCancelled != null && isCancelled()) {
        throw Exception('Download cancelled by user');
      }

      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Failed to download drop: ${response.statusCode}');
      }

      final total = response.contentLength;
      final bytesBuilder = BytesBuilder(copy: false);
      int received = 0;

      await for (final chunk in response) {
        if (isCancelled != null && isCancelled()) {
          request.abort();
          throw Exception('Download cancelled by user');
        }
        bytesBuilder.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }

      return bytesBuilder.takeBytes();
    } finally {
      httpClient.close();
    }
  }

  static Future<String> downloadDropToFile({
    required String baseUrl,
    required String id,
    required String outputPath,
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    final httpClient = HttpClient();

    try {
      if (isCancelled != null && isCancelled()) {
        throw Exception('Download cancelled by user');
      }

      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        final bytesBuilder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          bytesBuilder.add(chunk);
        }
        final errorBody = utf8.decode(
          bytesBuilder.takeBytes(),
          allowMalformed: true,
        );
        final parsedError = _parseError(errorBody);
        throw Exception(
          parsedError ?? 'Failed to download drop: ${response.statusCode}',
        );
      }

      final total = response.contentLength;
      int received = 0;

      final stream = response.map((chunk) {
        if (isCancelled != null && isCancelled()) {
          request.abort();
          throw Exception('Download cancelled by user');
        }
        received += chunk.length;
        onProgress?.call(received, total);
        return chunk;
      });

      await sink.addStream(stream);
      await sink.close();
      return outputPath;
    } catch (e) {
      await sink.close();
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      httpClient.close();
    }
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
