import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'fast_drop_model.dart';

class FastDropService {
  static final http.Client _client = http.Client();

  static String _sanitizeUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  static Future<List<FastDropItem>> fetchDrops(String baseUrl) async {
    final url = '${_sanitizeUrl(baseUrl)}/api/drop';
    final response = await _client
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
  }) async {
    final url = '${_sanitizeUrl(baseUrl)}/api/drop';
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      'X-Filename': Uri.encodeComponent(filename),
      'X-Retention': retention,
      'X-Source': source,
      'Content-Type': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
    });
    request.bodyBytes = bytes;
    final streamedResponse = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to upload drop: ${response.statusCode}',
      );
    }
  }

  static Future<void> deleteDrop(String baseUrl, String id) async {
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final response = await _client
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
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id/keep';
    final response = await _client
        .patch(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to update drop: ${response.statusCode}',
      );
    }
  }

  static Future<Uint8List> downloadDrop(String baseUrl, String id) async {
    final url = '${_sanitizeUrl(baseUrl)}/api/drop/$id';
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download drop: ${response.statusCode}');
    }
  }
}
