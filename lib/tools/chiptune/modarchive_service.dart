import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Raised when a random tune cannot be fetched or parsed from The Mod Archive.
class ModArchiveException implements Exception {
  final String message;
  const ModArchiveException(this.message);
  @override
  String toString() => message;
}

/// Metadata plus raw module bytes for a tune fetched from The Mod Archive.
class ModArchiveTune {
  final int moduleId;
  final String fileName;
  final String title;
  final String format;
  final int? channels;
  final String? sizeText;
  final String? genre;
  final Uint8List bytes;

  const ModArchiveTune({
    required this.moduleId,
    required this.fileName,
    required this.title,
    required this.format,
    required this.bytes,
    this.channels,
    this.sizeText,
    this.genre,
  });

  /// Public module page on modarchive.org — used for attribution / credits.
  String get pageUrl =>
      'https://modarchive.org/index.php?request=view_by_moduleid&query=$moduleId';
}

/// Fetches and parses random tracker modules from The Mod Archive
/// (modarchive.org), a long-running free repository of tracker music.
///
/// Flow: load the random-module HTML page, scrape its metadata and download
/// reference, then pull the actual module file from the download API.
class ModArchiveService {
  static const String _randomPageUrl =
      'https://modarchive.org/index.php?request=view_random';
  static const String _downloadBase =
      'https://api.modarchive.org/downloads.php?moduleid=';

  /// modarchive blocks requests without a browser-like agent.
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (compatible; ToolLab Chiptune Player)',
  };

  static final RegExp _downloadRe = RegExp(
    r'downloads\.php\?moduleid=(\d+)#([^"]+)"',
  );
  static final RegExp _titleRe = RegExp(r'<h1>(.*?)<span', dotAll: true);
  static final RegExp _formatRe = RegExp(r'Format:\s*([^<]+)<');
  static final RegExp _channelsRe = RegExp(r'Channels:\s*(\d+)');
  static final RegExp _sizeRe = RegExp(r'Uncompressed Size:\s*([^<]+)<');
  static final RegExp _genreRe = RegExp(r'Genre:\s*([^<]+)<');

  /// Loads modarchive's random-module page, parses its metadata, then
  /// downloads the referenced module file.
  ///
  /// Throws [ModArchiveException] on any network or parse failure.
  Future<ModArchiveTune> fetchRandom() async {
    final client = http.Client();
    try {
      final html = await _getRandomPage(client);
      final match = _downloadRe.firstMatch(html);
      if (match == null) {
        throw const ModArchiveException(
          'Could not find a download link on the random page',
        );
      }
      final moduleId = int.parse(match.group(1)!);
      final fileName = _unescapeHtml(match.group(2)!.trim());
      final bytes = await _downloadModule(client, moduleId);

      return ModArchiveTune(
        moduleId: moduleId,
        fileName: fileName,
        title: _parseTitle(html, fileName),
        format: _match(_formatRe, html) ?? _extFormat(fileName),
        channels: int.tryParse(_match(_channelsRe, html) ?? ''),
        sizeText: _match(_sizeRe, html),
        genre: _normalizeGenre(_match(_genreRe, html)),
        bytes: bytes,
      );
    } on ModArchiveException {
      rethrow;
    } catch (e) {
      throw ModArchiveException('Failed to fetch random tune: $e');
    } finally {
      client.close();
    }
  }

  Future<String> _getRandomPage(http.Client client) async {
    final res = await client.get(Uri.parse(_randomPageUrl), headers: _headers);
    if (res.statusCode != 200) {
      throw ModArchiveException(
        'The Mod Archive returned HTTP ${res.statusCode}',
      );
    }
    return res.body;
  }

  Future<Uint8List> _downloadModule(http.Client client, int moduleId) async {
    final res = await client.get(
      Uri.parse('$_downloadBase$moduleId'),
      headers: _headers,
    );
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw ModArchiveException(
        'Module download failed (HTTP ${res.statusCode})',
      );
    }
    return res.bodyBytes;
  }

  String _parseTitle(String html, String fallback) {
    final raw = _match(_titleRe, html);
    final title = raw == null ? '' : _unescapeHtml(raw.trim());
    return title.isEmpty ? fallback : title;
  }

  String? _match(RegExp re, String html) {
    final value = re.firstMatch(html)?.group(1)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? _normalizeGenre(String? genre) {
    if (genre == null) return null;
    final lower = genre.toLowerCase();
    return (lower == 'n/a' || lower == 'unknown') ? null : genre;
  }

  String _extFormat(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toUpperCase();
  }

  String _unescapeHtml(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}
