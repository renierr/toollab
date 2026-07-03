import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Raised when a module cannot be fetched from the user's own backend
/// collection (browser-toolkit `/api/chiptune`).
class ChiptuneCollectionException implements Exception {
  final String message;
  const ChiptuneCollectionException(this.message);
  @override
  String toString() => message;
}

/// A module served from the user's backend collection folder.
class CollectionTune {
  final String id;
  final String fileName;
  final String format;
  final String title;
  final Uint8List bytes;

  const CollectionTune({
    required this.id,
    required this.fileName,
    required this.format,
    required this.title,
    required this.bytes,
  });
}

/// Talks to the browser-toolkit backend's chiptune collection API, mirroring
/// the modarchive random flow but against the user's own server folder.
class ChiptuneCollectionService {
  /// Fetches a random module's metadata from the server, then downloads its
  /// bytes. [baseUrl] is the configured sync server URL.
  Future<CollectionTune> fetchRandom(String baseUrl) async {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw const ChiptuneCollectionException('No server configured');
    }
    final client = http.Client();
    try {
      final res = await client.get(Uri.parse('$base/api/chiptune/random'));
      if (res.statusCode != 200) {
        throw ChiptuneCollectionException(
          'Server returned HTTP ${res.statusCode}',
        );
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw ChiptuneCollectionException(
          (json['error'] ?? 'No modules in collection').toString(),
        );
      }
      final downloadUrl = json['downloadUrl'] as String?;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw const ChiptuneCollectionException(
          'Server returned no download link',
        );
      }
      final fileRes = await client.get(Uri.parse('$base$downloadUrl'));
      if (fileRes.statusCode != 200 || fileRes.bodyBytes.isEmpty) {
        throw ChiptuneCollectionException(
          'Module download failed (HTTP ${fileRes.statusCode})',
        );
      }
      final fileName = (json['fileName'] ?? 'module').toString();
      return CollectionTune(
        id: (json['id'] ?? '').toString(),
        fileName: fileName,
        format: (json['format'] ?? '').toString(),
        title: (json['title'] ?? fileName).toString(),
        bytes: fileRes.bodyBytes,
      );
    } on ChiptuneCollectionException {
      rethrow;
    } catch (e) {
      throw ChiptuneCollectionException('Failed to fetch from collection: $e');
    } finally {
      client.close();
    }
  }
}
