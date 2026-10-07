import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:rhttp/rhttp.dart' as rhttp;
import 'package:tool_lab/services/app_http_client.dart';

import 'models/paperless_document.dart';
import 'models/paperless_filter.dart';
import 'models/paperless_label.dart';
import 'models/paperless_page_result.dart';
import 'models/paperless_statistics.dart';
import 'models/paperless_task.dart';

enum PaperlessErrorKind {
  network,
  unauthorized,
  invalidCredentials,
  notFound,
  rejected,
  server,
  invalidResponse,
}

class PaperlessException implements Exception {
  final PaperlessErrorKind kind;
  final String detail;

  /// Existing document id when the server rejected the file as a duplicate.
  final int? duplicateDocumentId;

  const PaperlessException(
    this.kind, [
    this.detail = '',
    this.duplicateDocumentId,
  ]);

  @override
  String toString() =>
      'PaperlessException(${kind.name}): $detail${duplicateDocumentId == null ? '' : ' (#$duplicateDocumentId)'}';
}

class PaperlessServerInfo {
  final int documentCount;
  final String? version;

  const PaperlessServerInfo({required this.documentCount, this.version});
}

/// REST client for paperless-ng and paperless-ngx. Sticks to the API v1
/// surface both servers share, authenticated with a long-lived token.
class PaperlessApi {
  final Uri baseUri;
  final String token;

  const PaperlessApi({required this.baseUri, required this.token});

  static const _timeout = Duration(seconds: 20);
  static const _pageSize = 25;
  static const _listFields =
      'id,title,created,added,correspondent,document_type,tags,'
      'archive_serial_number,original_file_name';
  static final _taskIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Accepts what users paste: the web UI address, with or without `/api`.
  static Uri? parseBaseUri(String input) {
    var text = input.trim();
    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('/api')) text = text.substring(0, text.length - 4);
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (!uri.isScheme('http') && !uri.isScheme('https')) return null;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
  }

  String get _basePath =>
      baseUri.path.endsWith('/') ? baseUri.path : '${baseUri.path}/';

  Uri _uri(String path, [Map<String, String>? query]) => baseUri.replace(
    path: '${_basePath}api/$path',
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  Uri documentWebUri(int id) =>
      baseUri.replace(path: '${_basePath}documents/$id');

  Map<String, String> get _headers => {
    'Authorization': 'Token $token',
    'Accept': 'application/json',
  };

  static Future<String> obtainToken(
    Uri baseUri,
    String username,
    String password,
  ) async {
    final api = PaperlessApi(baseUri: baseUri, token: '');
    final client = await AppHttpClient.client;
    final http.Response res;
    try {
      res = await client
          .post(
            api._uri('token/'),
            headers: const {'Accept': 'application/json'},
            body: {'username': username, 'password': password},
          )
          .timeout(_timeout);
    } catch (e) {
      throw PaperlessException(PaperlessErrorKind.network, '$e');
    }
    if (res.statusCode == 400) {
      throw const PaperlessException(PaperlessErrorKind.invalidCredentials);
    }
    _check(res.statusCode);
    final token = _decodeMap(res)['token'];
    if (token is! String || token.isEmpty) {
      throw const PaperlessException(PaperlessErrorKind.invalidResponse);
    }
    return token;
  }

  Future<PaperlessServerInfo> serverInfo() async {
    final res = await _get('documents/', {'page_size': '1', 'fields': 'id'});
    return PaperlessServerInfo(
      documentCount: _decodeMap(res)['count'] as int? ?? 0,
      version: res.headers['x-version'],
    );
  }

  Future<PaperlessPageResult<PaperlessDocument>> documents({
    required PaperlessFilter filter,
    required int page,
  }) async {
    final res = await _get('documents/', {
      ...filter.toQuery(),
      'page': '$page',
      'page_size': '$_pageSize',
      'fields': _listFields,
      'truncate_content': 'true',
    });
    return PaperlessPageResult.fromJson(
      _decodeMap(res),
      PaperlessDocument.fromJson,
    );
  }

  Future<List<PaperlessLabel>> tags() => _allLabels('tags/');

  Future<List<PaperlessLabel>> correspondents() =>
      _allLabels('correspondents/');

  Future<List<PaperlessLabel>> documentTypes() => _allLabels('document_types/');

  // Pages by number instead of following `next`: behind a reverse proxy the
  // server builds that link from its internal host name.
  Future<List<PaperlessLabel>> _allLabels(String path) async {
    final items = <PaperlessLabel>[];
    for (var page = 1; ; page++) {
      final res = await _get(path, {
        'page': '$page',
        'page_size': '250',
        'ordering': 'name',
      });
      final result = PaperlessPageResult.fromJson(
        _decodeMap(res),
        PaperlessLabel.fromJson,
      );
      items.addAll(result.items);
      if (!result.hasNext || result.items.isEmpty) return items;
    }
  }

  Future<PaperlessStatistics> statistics() async =>
      PaperlessStatistics.fromJson(_decodeMap(await _get('statistics/')));

  Future<Uint8List> thumbnail(int id) async =>
      (await _get('documents/$id/thumb/')).bodyBytes;

  /// Null when the server cannot report on tasks (paperless-ng).
  Future<PaperlessTask?> task(String taskId) async {
    final http.Response res;
    try {
      res = await _get('tasks/', {'task_id': taskId});
    } on PaperlessException catch (e) {
      if (e.kind == PaperlessErrorKind.notFound) return null;
      rethrow;
    }
    final decoded = _decode(res);
    final list = decoded is List ? decoded : (decoded as Map)['results'];
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    return first is Map<String, dynamic> ? PaperlessTask.fromJson(first) : null;
  }

  /// Streams the archived (OCR'd) version, or the original when there is none,
  /// into the file [createTarget] returns for the server-provided name.
  Future<({String path, String mimeType})> download(
    PaperlessDocument document, {
    required Future<File> Function(String fileName) createTarget,
    void Function(int received, int total)? onProgress,
  }) async {
    final client = await AppHttpClient.createStreamingClient();
    try {
      final res = await client.getStream(
        _uri('documents/${document.id}/download/').toString(),
        headers: rhttp.HttpHeaders.rawMap(_headers),
        onReceiveProgress: onProgress,
      );
      final mimeType =
          _header(res.headers, 'content-type')?.split(';').first.trim() ??
          'application/octet-stream';
      final fileName =
          _fileNameFromDisposition(
            _header(res.headers, 'content-disposition'),
          ) ??
          _fallbackFileName(document, mimeType);
      final file = await createTarget(fileName);
      final sink = file.openWrite();
      try {
        await sink.addStream(res.body);
      } finally {
        await sink.close();
      }
      return (path: file.path, mimeType: mimeType);
    } on rhttp.RhttpStatusCodeException catch (e) {
      _check(e.statusCode);
      rethrow;
    } on rhttp.RhttpException catch (e) {
      throw PaperlessException(PaperlessErrorKind.network, '$e');
    } finally {
      client.dispose();
    }
  }

  /// Returns the consumption task id on paperless-ngx, null on paperless-ng,
  /// which only answers "OK".
  Future<String?> upload({
    required String path,
    required String fileName,
    String? title,
    int? correspondentId,
    int? documentTypeId,
    Iterable<int> tagIds = const [],
    void Function(int sent, int total)? onProgress,
  }) async {
    final url = _uri('documents/post_document/');
    final request = http.MultipartRequest('POST', url);
    if (title != null && title.isNotEmpty) request.fields['title'] = title;
    if (correspondentId != null) {
      request.fields['correspondent'] = '$correspondentId';
    }
    if (documentTypeId != null) {
      request.fields['document_type'] = '$documentTypeId';
    }
    // `fields` is a map, but Paperless wants one `tags` part per tag. A part
    // without a file name is still parsed as a plain form field.
    for (final tagId in tagIds) {
      request.files.add(http.MultipartFile.fromString('tags', '$tagId'));
    }
    request.files.add(
      await http.MultipartFile.fromPath('document', path, filename: fileName),
    );

    // Encoded here and streamed through rhttp, whose http.Client adapter
    // would buffer the whole body and report no progress.
    final length = request.contentLength;
    final body = request.finalize();
    final client = await AppHttpClient.createStreamingClient();
    try {
      final res = await client.post(
        url.toString(),
        headers: rhttp.HttpHeaders.rawMap({
          ..._headers,
          'Content-Type': request.headers['content-type']!,
        }),
        body: rhttp.HttpBody.stream(body, length: length),
        onSendProgress: onProgress,
      );
      final taskId = _tryDecode(res.body);
      return taskId is String && _taskIdPattern.hasMatch(taskId)
          ? taskId
          : null;
    } on rhttp.RhttpStatusCodeException catch (e) {
      if (e.statusCode == 400) {
        throw PaperlessException(
          PaperlessErrorKind.rejected,
          _validationMessage(e.body),
        );
      }
      _check(e.statusCode);
      rethrow;
    } on rhttp.RhttpException catch (e) {
      throw PaperlessException(PaperlessErrorKind.network, '$e');
    } finally {
      client.dispose();
    }
  }

  Future<http.Response> _get(String path, [Map<String, String>? query]) async {
    final client = await AppHttpClient.client;
    final http.Response res;
    try {
      res = await client
          .get(_uri(path, query), headers: _headers)
          .timeout(_timeout);
    } catch (e) {
      throw PaperlessException(PaperlessErrorKind.network, '$e');
    }
    _check(res.statusCode);
    return res;
  }

  static void _check(int status) {
    if (status >= 200 && status < 300) return;
    throw switch (status) {
      401 || 403 => const PaperlessException(PaperlessErrorKind.unauthorized),
      404 => const PaperlessException(PaperlessErrorKind.notFound),
      _ => PaperlessException(PaperlessErrorKind.server, 'HTTP $status'),
    };
  }

  // A 200 HTML page usually means an auth proxy answered instead of Paperless.
  static Object? _decode(http.Response res) {
    final decoded = _tryDecode(
      utf8.decode(res.bodyBytes, allowMalformed: true),
    );
    if (decoded == null) {
      throw const PaperlessException(PaperlessErrorKind.invalidResponse);
    }
    return decoded;
  }

  static Map<String, dynamic> _decodeMap(http.Response res) {
    final decoded = _decode(res);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const PaperlessException(PaperlessErrorKind.invalidResponse);
  }

  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String _validationMessage(Object? body) {
    final text = body is String
        ? body
        : body is List<int>
        ? utf8.decode(body, allowMalformed: true)
        : '';
    final decoded = _tryDecode(text);
    if (decoded is Map) {
      final parts = <String>[];
      for (final entry in decoded.entries) {
        final values = entry.value is List
            ? entry.value as List
            : [entry.value];
        for (final value in values) {
          final message = '$value'.trim();
          if (message.isEmpty) continue;
          // DRF nests the offending field as the key
          // ({"document": ["No file was submitted."]}); keep it so the
          // message says *what* was rejected instead of just *that* it was.
          parts.add('${entry.key}: $message');
        }
      }
      if (parts.isNotEmpty) return parts.join(' ');
    }
    if (decoded is List) {
      final parts = decoded
          .map((v) => '$v'.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts.join(' ');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    // An auth proxy answering with HTML is not a Paperless reason; don't
    // paste a page of markup into the upload list.
    if (trimmed.startsWith('<')) return '';
    return trimmed.length > 500 ? '${trimmed.substring(0, 500)}…' : trimmed;
  }

  static String? _header(List<(String, String)> headers, String name) {
    for (final (key, value) in headers) {
      if (key.toLowerCase() == name) return value;
    }
    return null;
  }

  static String? _fileNameFromDisposition(String? header) {
    if (header == null) return null;
    final extended = RegExp(
      r"filename\*\s*=\s*[^']*'[^']*'([^;]+)",
      caseSensitive: false,
    ).firstMatch(header);
    if (extended != null) {
      try {
        return _safeFileName(Uri.decodeComponent(extended.group(1)!.trim()));
      } on ArgumentError {
        // Malformed escapes: fall through to the plain parameter.
      }
    }
    final plain = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(header);
    return plain == null ? null : _safeFileName(plain.group(1)!.trim());
  }

  static String _fallbackFileName(PaperlessDocument document, String mime) {
    final ext = switch (mime) {
      'application/pdf' => 'pdf',
      'image/jpeg' => 'jpg',
      _ when mime.startsWith('image/') => mime.substring(6),
      _ => 'bin',
    };
    final base = document.title.isEmpty
        ? 'document-${document.id}'
        : document.title;
    return _safeFileName('$base.$ext');
  }

  static String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
    return cleaned.isEmpty ? 'document' : cleaned;
  }
}
