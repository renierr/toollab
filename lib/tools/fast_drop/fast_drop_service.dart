import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'fast_drop_model.dart';

Future<void> _runFastDropTransferIsolate(Map<String, Object> config) async {
  final messages = config['messages']! as SendPort;
  final control = ReceivePort();
  var cancelled = false;
  control.listen((_) => cancelled = true);
  messages.send({'type': 'ready', 'port': control.sendPort});

  final client = HttpClient();
  final stopwatch = Stopwatch()..start();
  var lastProgressAt = Duration.zero;

  void reportProgress(int transferred, int total) {
    if (stopwatch.elapsed - lastProgressAt <
            const Duration(milliseconds: 120) &&
        transferred != total) {
      return;
    }
    lastProgressAt = stopwatch.elapsed;
    messages.send({
      'type': 'progress',
      'transferred': transferred,
      'total': total,
    });
  }

  try {
    final timeout = Duration(milliseconds: config['timeoutMs']! as int);
    client.connectionTimeout = timeout;
    final url = Uri.parse(config['url']! as String);

    if (config['operation'] == 'upload') {
      final file = File(config['filePath']! as String);
      final total = await file.length();
      var sent = 0;
      final request = await client.postUrl(url);
      request.bufferOutput = false;
      request.headers.set('X-Filename', config['filename']! as String);
      request.headers.set('X-Retention', config['retention']! as String);
      request.headers.set('X-Source', config['source']! as String);
      request.headers.set('Content-Type', config['mimeType']! as String);
      request.contentLength = total;

      await request.addStream(
        file.openRead().map((chunk) {
          if (cancelled) throw Exception('Upload cancelled by user');
          sent += chunk.length;
          reportProgress(sent, total);
          return chunk;
        }),
      );
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        final data = jsonDecode(body);
        throw Exception(
          data['error'] ?? 'Failed to upload drop: ${response.statusCode}',
        );
      }
    } else {
      final output = File(config['outputPath']! as String);
      await output.parent.create(recursive: true);
      final sink = output.openWrite();
      try {
        final request = await client.getUrl(url);
        final response = await request.close().timeout(timeout);
        if (response.statusCode != 200) {
          throw Exception('Failed to download drop: ${response.statusCode}');
        }
        final total = response.contentLength;
        var received = 0;
        await sink.addStream(
          response.map((chunk) {
            if (cancelled) throw Exception('Download cancelled by user');
            received += chunk.length;
            reportProgress(received, total);
            return chunk;
          }),
        );
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await output.exists()) await output.delete();
        rethrow;
      }
    }
    messages.send({'type': 'complete'});
  } catch (error) {
    messages.send({'type': 'error', 'message': error.toString()});
  } finally {
    control.close();
    client.close(force: true);
  }
}

class FastDropService {
  static Future<void> _runTransfer({
    required Map<String, Object> config,
    void Function(int transferred, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final messages = ReceivePort();
    SendPort? control;
    Timer? cancellationTimer;
    final completion = Completer<void>();
    final subscription = messages.listen((message) {
      final data = Map<String, Object?>.from(message as Map);
      switch (data['type']) {
        case 'ready':
          control = data['port']! as SendPort;
          cancellationTimer = Timer.periodic(const Duration(milliseconds: 50), (
            _,
          ) {
            if (isCancelled?.call() ?? false) control?.send(null);
          });
        case 'progress':
          onProgress?.call(data['transferred']! as int, data['total']! as int);
        case 'complete':
          completion.complete();
        case 'error':
          completion.completeError(Exception(data['message']! as String));
      }
    });

    try {
      await Isolate.spawn(_runFastDropTransferIsolate, {
        ...config,
        'messages': messages.sendPort,
      });
      await completion.future;
    } finally {
      cancellationTimer?.cancel();
      await subscription.cancel();
      messages.close();
    }
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

    await _runTransfer(
      config: {
        'operation': 'upload',
        'url': url,
        'filePath': filePath,
        'filename': Uri.encodeComponent(filename),
        'retention': retention,
        'source': source,
        'mimeType': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        'timeoutMs': timeout.inMilliseconds,
      },
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
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
    await _runTransfer(
      config: {
        'operation': 'download',
        'url': url,
        'outputPath': outputPath,
        'timeoutMs': const Duration(minutes: 10).inMilliseconds,
      },
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return outputPath;
  }
}
