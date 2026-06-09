import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:rhttp/rhttp.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'fast_drop_model.dart';

class FastDropService {
  static http.Client? _client;

  static Future<http.Client> get _clientFuture async {
    _client ??= await RhttpCompatibleClient.create();
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
    final response = await client
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
    const chunkSize = 64 * 1024;

    final request = http.StreamedRequest('POST', Uri.parse(url));
    request.headers.addAll({
      'X-Filename': Uri.encodeComponent(filename),
      'X-Retention': retention,
      'X-Source': source,
      'Content-Type': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
    });
    request.contentLength = total;

    final responseFuture = client.send(request);

    try {
      int sent = 0;
      for (int i = 0; i < total; i += chunkSize) {
        if (isCancelled != null && isCancelled()) {
          request.sink.close();
          throw Exception('Upload cancelled by user');
        }
        final end = (i + chunkSize).clamp(0, total);
        request.sink.add(bytes.sublist(i, end));
        sent = end;
        onProgress?.call(sent, total);
      }
      await request.sink.close();

      final timeout = _adaptiveTimeout(
        bytes: total,
        baseSeconds: 30,
        bytesPerSecond: 100 * 1024,
      );
      final streamedResponse = await responseFuture.timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ?? 'Failed to upload drop: ${response.statusCode}',
        );
      }
    } catch (e) {
      request.sink.close();
      rethrow;
    }
  }

  static Future<void> deleteDrop(String baseUrl, String id) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final response = await client
        .delete(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to delete drop: ${response.statusCode}',
      );
    }
  }

  static Future<void> keepDrop(String baseUrl, String id) async {
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/keep';
    final response = await client
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
    final client = await _clientFuture;
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await client.send(request);
    final total = streamedResponse.contentLength ?? -1;

    final tempName = 'fast_drop_download_$id';
    final tempPath = await TempFileManager.createFile(tempName);
    final tempFile = File(tempPath);
    final sink = tempFile.openWrite();

    try {
      int received = 0;
      await for (final chunk in streamedResponse.stream) {
        if (isCancelled != null && isCancelled()) {
          throw Exception('Download cancelled by user');
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();

      final timeout = _adaptiveTimeout(
        bytes: received,
        baseSeconds: 10,
        bytesPerSecond: 200 * 1024,
      );

      final bytes = await tempFile.readAsBytes().timeout(timeout);
      await TempFileManager.deleteFile(tempName);
      return bytes;
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) {
        try {
          await TempFileManager.deleteFile(tempName);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
