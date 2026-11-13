import 'dart:async';

import 'package:flutter/services.dart';

/// Feature status for GenAI APIs.
enum FeatureStatus { unavailable, downloadable, downloading, available }

/// A prompt generator that sends requests to the on-device Gemini Nano model.
class Prompt {
  static const MethodChannel _channel = MethodChannel(
    'google_mlkit_genai_prompt',
  );

  static final Map<String, StreamController<String>> _streams = {};
  static final Map<String, Prompt> _instances = {};
  static int _requestCounter = 0;
  static bool _handlerInstalled = false;

  final String id = DateTime.now().microsecondsSinceEpoch.toString();

  void Function(int bytesToDownload)? _onDownloadStarted;
  void Function(int totalBytesDownloaded)? _onDownloadProgress;
  bool? _systemPromptAvailable;

  Prompt() {
    _instances[id] = this;
    if (!_handlerInstalled) {
      _channel.setMethodCallHandler(_handleNativeCall);
      _handlerInstalled = true;
    }
  }

  static Future<void> _handleNativeCall(MethodCall call) async {
    final args = (call.arguments as Map).cast<String, Object?>();
    switch (call.method) {
      case 'genai#onStreamChunk':
        _streams[args['requestId']]?.add(args['text']! as String);
      case 'genai#onDownloadEvent':
        final prompt = _instances[args['id']];
        final bytes = (args['bytes']! as num).toInt();
        if (args['type'] == 'started') {
          prompt?._onDownloadStarted?.call(bytes);
        } else {
          prompt?._onDownloadProgress?.call(bytes);
        }
    }
  }

  static String _nextRequestId() => 'r${++_requestCounter}';

  Future<FeatureStatus> checkFeatureStatus() async {
    final result = await _channel.invokeMethod<int>(
      'genai#checkFeatureStatus',
      {'id': id},
    );
    return FeatureStatus.values[result ?? 0];
  }

  /// Whether the model accepts a separate system instruction. When it does
  /// not, [runInference] folds the instruction into the prompt text.
  Future<bool> isSystemPromptAvailable() async {
    return _systemPromptAvailable ??=
        await _channel.invokeMethod<bool>('genai#isSystemPromptAvailable', {
          'id': id,
        }) ??
        false;
  }

  /// Completes when the model is downloaded; throws [PlatformException] on failure.
  Future<void> downloadFeature({
    void Function(int bytesToDownload)? onDownloadStarted,
    void Function(int totalBytesDownloaded)? onDownloadProgress,
  }) async {
    _onDownloadStarted = onDownloadStarted;
    _onDownloadProgress = onDownloadProgress;
    try {
      await _channel.invokeMethod('genai#downloadFeature', {'id': id});
    } finally {
      _onDownloadStarted = null;
      _onDownloadProgress = null;
    }
  }

  Future<Map<String, Object?>> _requestArgs(
    String requestId,
    String text,
    String? systemInstruction,
    Uint8List? imageData,
  ) async {
    final hasSystem = systemInstruction != null && systemInstruction.isNotEmpty;
    final native = hasSystem && await isSystemPromptAvailable();
    return {
      'id': id,
      'requestId': requestId,
      'text': hasSystem && !native ? '$systemInstruction\n\n$text' : text,
      'systemInstruction': native ? systemInstruction : null,
      'imageData': imageData,
    };
  }

  Future<String> runInference(
    String text, {
    String? systemInstruction,
    Uint8List? imageData,
  }) async {
    final requestId = _nextRequestId();
    final result = await _channel.invokeMapMethod<String, Object?>(
      'genai#runInference',
      await _requestArgs(requestId, text, systemInstruction, imageData),
    );
    return result?['text'] as String? ?? '';
  }

  /// Emits text chunks as the model generates them. Cancelling the
  /// subscription cancels the native request.
  Stream<String> runInferenceStreaming(
    String text, {
    String? systemInstruction,
    Uint8List? imageData,
  }) {
    final requestId = _nextRequestId();
    late final StreamController<String> controller;
    var finished = false;

    Future<void> start() async {
      try {
        final args = await _requestArgs(
          requestId,
          text,
          systemInstruction,
          imageData,
        );
        if (controller.isClosed) return;
        await _channel.invokeMethod('genai#runInferenceStreaming', args);
      } on PlatformException catch (e) {
        if (e.code != 'Cancelled' && !controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        finished = true;
        _streams.remove(requestId);
        if (!controller.isClosed) await controller.close();
      }
    }

    controller = StreamController<String>(
      onListen: start,
      onCancel: () async {
        _streams.remove(requestId);
        if (!finished) {
          await _channel.invokeMethod('genai#cancelRequest', {
            'requestId': requestId,
          });
        }
      },
    );
    _streams[requestId] = controller;
    return controller.stream;
  }

  Future<void> close() {
    _instances.remove(id);
    return _channel.invokeMethod('genai#closePrompt', {'id': id});
  }
}
