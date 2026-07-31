import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'fast_drop_model.dart';

Future<void> _runFastDropTransferIsolate(Map<String, Object> config) async {
  final messages = config['messages']! as SendPort;
  final control = ReceivePort();
  final client = HttpClient();
  final stopwatch = Stopwatch()..start();
  var lastProgressAt = Duration.zero;
  var cancelled = false;
  var stalled = false;

  // Aborting a *stalled* transfer needs more than a flag the chunk callback
  // checks — no further chunk ever arrives — so the connection is torn down.
  void abort() => client.close(force: true);

  control.listen((_) {
    cancelled = true;
    abort();
  });
  messages.send({'type': 'ready', 'port': control.sendPort});

  var lastActivityAt = Duration.zero;
  var watchdogArmed = false;
  final stallTimeout = Duration(milliseconds: config['stallTimeoutMs']! as int);

  // Only armed while body bytes are expected to flow. Waiting for response
  // headers is not a stall — the server may legitimately think for a while
  // before answering — that phase is bounded by responseTimeout instead.
  void armWatchdog() {
    lastActivityAt = stopwatch.elapsed;
    watchdogArmed = true;
  }

  final stallWatchdog = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!watchdogArmed) return;
    if (stopwatch.elapsed - lastActivityAt > stallTimeout) {
      stalled = true;
      abort();
    }
  });

  void reportProgress(int transferred, int total) {
    lastActivityAt = stopwatch.elapsed;
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
    client.connectionTimeout = Duration(
      milliseconds: config['connectTimeoutMs']! as int,
    );
    final responseTimeout = Duration(
      milliseconds: config['responseTimeoutMs']! as int,
    );
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

      armWatchdog();
      await request.addStream(
        file.openRead().map((chunk) {
          if (cancelled) throw Exception('Upload cancelled by user');
          sent += chunk.length;
          reportProgress(sent, total);
          return chunk;
        }),
      );
      watchdogArmed = false;
      final response = await request.close().timeout(responseTimeout);
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
        final response = await request.close().timeout(responseTimeout);
        if (response.statusCode != 200) {
          throw Exception('Failed to download drop: ${response.statusCode}');
        }
        final total = response.contentLength;
        var received = 0;
        armWatchdog();
        await sink.addStream(
          response.map((chunk) {
            if (cancelled) throw Exception('Download cancelled by user');
            received += chunk.length;
            reportProgress(received, total);
            return chunk;
          }),
        );
        watchdogArmed = false;
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await output.exists()) await output.delete();
        rethrow;
      }
    }
    messages.send({'type': 'complete'});
  } catch (error) {
    // Tearing the connection down to abort races with the chunk callback, so
    // the raw socket error is discarded in favour of the actual cause.
    final label = config['operation'] == 'upload' ? 'Upload' : 'Download';
    final message = switch ((cancelled, stalled)) {
      (true, _) => '$label cancelled by user',
      (false, true) => '$label stalled: no data for ${stallTimeout.inSeconds}s',
      _ => error.toString(),
    };
    messages.send({'type': 'error', 'message': message});
  } finally {
    stallWatchdog.cancel();
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

  /// Transfers are bounded by inactivity, not by total duration: a slow but
  /// progressing transfer of any size is allowed to finish, while a dead
  /// connection is dropped quickly.
  static const _connectTimeout = Duration(seconds: 15);
  static const _stallTimeout = Duration(seconds: 30);

  /// Headers may legitimately lag the last body byte while the server flushes
  /// a large upload to disk, so the response gets its own, longer budget.
  static const _responseTimeout = Duration(minutes: 5);

  static Map<String, Object> _timeoutConfig() => {
    'connectTimeoutMs': _connectTimeout.inMilliseconds,
    'stallTimeoutMs': _stallTimeout.inMilliseconds,
    'responseTimeoutMs': _responseTimeout.inMilliseconds,
  };

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

    if (isCancelled != null && isCancelled()) {
      throw Exception('Upload cancelled by user');
    }

    await _runTransfer(
      config: {
        'operation': 'upload',
        'url': url,
        'filePath': filePath,
        'filename': Uri.encodeComponent(filename),
        'retention': retention,
        'source': source,
        'mimeType': mimeType.isEmpty ? 'application/octet-stream' : mimeType,
        ..._timeoutConfig(),
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
        ..._timeoutConfig(),
      },
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return outputPath;
  }
}
