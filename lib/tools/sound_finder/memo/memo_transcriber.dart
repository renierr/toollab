import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:whisper_ggml/whisper_ggml.dart';

import '../../../helpers/debug_log.dart';
import '../../../helpers/temp_file_manager.dart';
import '../../../services/app_http_client.dart';
import '../../../services/background_work_lease.dart';
import '../../../services/database_service.dart';
import '../config.dart';
import 'memo_clip.dart';
import 'memo_store.dart';
import 'memo_transcript.dart';
import 'memo_whisper_audio.dart';

/// Chunk progress of a running transcription. whisper.cpp reports nothing
/// inside a 30 s window, so progress moves chunk by chunk.
class MemoTranscriptionProgress {
  final int done;
  final int total;
  final DateTime chunkStarted;
  final Duration? perChunk;

  const MemoTranscriptionProgress({
    required this.done,
    required this.total,
    required this.chunkStarted,
    this.perChunk,
  });

  double? get fraction => total == 0 || done == 0 ? null : done / total;

  /// Time left for the whole job, once one chunk has been measured.
  Duration? get remaining {
    final per = perChunk;
    if (per == null) return null;
    final left = per * (total - done) - DateTime.now().difference(chunkStarted);
    return left.isNegative ? Duration.zero : left;
  }

  /// Time left for the chunk that is running.
  Duration? get currentChunkLeft {
    final per = perChunk;
    if (per == null) return null;
    final left = per - DateTime.now().difference(chunkStarted);
    return left.isNegative ? Duration.zero : left;
  }
}

class MemoTranscriptionCancelled implements Exception {
  const MemoTranscriptionCancelled();
}

class MemoTranscriptionException implements Exception {
  final String message;
  const MemoTranscriptionException(this.message);

  @override
  String toString() => message;
}

/// Offline memo transcription with whisper.cpp. Holds the chosen model and
/// running jobs app-wide, so a transcription keeps going when its sheet closes.
class MemoTranscriber extends ChangeNotifier {
  static const _logPrefix = '[MemoTranscriber]';
  static const _kModel = 'memo_whisper_model';
  static const _kLanguage = 'memo_whisper_language';

  static const List<WhisperModel> models = [
    WhisperModel.base,
    WhisperModel.small,
  ];
  static const WhisperModel recommendedModel = WhisperModel.small;
  static const List<String> languages = ['auto', 'de', 'en'];

  /// Download size of the ggml files in MB.
  static int sizeMb(WhisperModel model) => switch (model) {
    WhisperModel.base => 148,
    WhisperModel.small => 488,
    _ => 0,
  };

  final WhisperController _controller = WhisperController();
  final TempFileScope _scope = TempFileManager.createScope();

  bool _loaded = false;
  WhisperModel? _model;
  String _language = 'auto';
  WhisperModel? _downloading;
  double? _downloadProgress;
  bool _cancelDownload = false;
  final Map<String, MemoTranscriptionProgress> _jobs = {};
  final Set<String> _cancelled = {};

  WhisperModel? get model => _model;
  String get language => _language;
  WhisperModel? get downloading => _downloading;

  /// 0..1, or null while the size is unknown.
  double? get downloadProgress => _downloadProgress;
  bool isTranscribing(String path) => _jobs.containsKey(path);
  MemoTranscriptionProgress? progress(String path) => _jobs[path];

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    final db = DatabaseService.instance;
    final id = SoundFinderTool.config.id;
    final name = await db.getSetting(id, _kModel);
    final language = await db.getSetting(id, _kLanguage);
    if (languages.contains(language)) _language = language!;
    final model = models.where((m) => m.modelName == name).firstOrNull;
    if (model != null && await File(await _path(model)).exists()) {
      _model = model;
    }
    notifyListeners();
  }

  Future<String> _path(WhisperModel model) => _controller.getPath(model);

  Future<void> setLanguage(String language) async {
    if (!languages.contains(language) || language == _language) return;
    _language = language;
    notifyListeners();
    await DatabaseService.instance.setSetting(
      SoundFinderTool.config.id,
      _kLanguage,
      language,
    );
  }

  /// Streams the model to disk, then replaces the previously chosen model.
  Future<bool> download(WhisperModel model) async {
    if (_downloading != null) return false;
    _downloading = model;
    _downloadProgress = null;
    _cancelDownload = false;
    notifyListeners();
    final target = await _path(model);
    final part = File('$target.part');
    IOSink? sink;
    try {
      final client = await AppHttpClient.client;
      final response = await client.send(http.Request('GET', model.modelUri));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      var received = 0;
      sink = part.openWrite();
      await for (final chunk in response.stream) {
        if (_cancelDownload) throw const MemoTranscriptionException('cancel');
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          final next = received / total;
          if (_downloadProgress == null || next - _downloadProgress! >= 0.005) {
            _downloadProgress = next;
            notifyListeners();
          }
        }
      }
      await sink.close();
      sink = null;
      await part.rename(target);
      final previous = _model;
      _model = model;
      await DatabaseService.instance.setSetting(
        SoundFinderTool.config.id,
        _kModel,
        model.modelName,
      );
      if (previous != null && previous != model) await _deleteFile(previous);
      return true;
    } catch (e) {
      if (!_cancelDownload) errorLog('$_logPrefix model download failed: $e');
      await sink?.close();
      if (await part.exists()) await part.delete();
      return false;
    } finally {
      _downloading = null;
      _downloadProgress = null;
      notifyListeners();
    }
  }

  void cancelDownload() => _cancelDownload = true;

  Future<void> removeModel() async {
    final model = _model;
    if (model == null) return;
    _model = null;
    notifyListeners();
    await _deleteFile(model);
    await DatabaseService.instance.deleteSetting(
      SoundFinderTool.config.id,
      _kModel,
    );
  }

  Future<void> _deleteFile(WhisperModel model) async {
    final file = File(await _path(model));
    if (await file.exists()) await file.delete();
  }

  /// Stops [path]'s transcription after the chunk that is running.
  void cancel(String path) {
    if (!_jobs.containsKey(path)) return;
    _cancelled.add(path);
    notifyListeners();
  }

  bool isCancelling(String path) => _cancelled.contains(path);

  /// Transcribes [clip] chunk by chunk, so [cancel] takes effect between
  /// chunks; whisper.cpp itself cannot be interrupted mid-run.
  Future<MemoTranscript> transcribe(
    MemoClip clip, {
    required String title,
  }) async {
    final model = _model;
    if (model == null) {
      throw const MemoTranscriptionException('No model installed');
    }
    if (_jobs.containsKey(clip.path)) {
      throw const MemoTranscriptionException('Already running');
    }
    _jobs[clip.path] = MemoTranscriptionProgress(
      done: 0,
      total: 0,
      chunkStarted: DateTime.now(),
    );
    _cancelled.remove(clip.path);
    notifyListeners();
    BackgroundWorkLease? lease;
    final stem = 'whisper_${DateTime.now().microsecondsSinceEpoch}';
    final temp = <String>['$stem.wav'];
    final whisper = Whisper(model: model);
    var loaded = false;
    try {
      lease = await BackgroundWorkLease.acquire(
        title: title,
        text: clip.name,
        logPrefix: _logPrefix,
      );
      final input = await _scope.createFile('$stem.wav');
      if (!await _convert(clip.path, input)) {
        throw const MemoTranscriptionException('Unsupported audio format');
      }
      final chunks = await _split(
        input,
        input.replaceFirst(RegExp(r'\.wav$'), ''),
      );
      for (var i = 0; i < chunks.length; i++) {
        temp
          ..add('${stem}_$i.wav')
          ..add('${stem}_$i.wav.wav');
      }
      final modelPath = await _path(model);
      final segments = <MemoTranscriptSegment>[];
      final threads = Platform.numberOfProcessors.clamp(1, 4);
      final started = DateTime.now();
      for (var i = 0; i < chunks.length; i++) {
        _jobs[clip.path] = MemoTranscriptionProgress(
          done: i,
          total: chunks.length,
          chunkStarted: DateTime.now(),
          perChunk: i == 0 ? null : DateTime.now().difference(started) ~/ i,
        );
        notifyListeners();
        unawaited(lease.update('${clip.name} · ${i + 1}/${chunks.length}'));
        if (_cancelled.contains(clip.path)) {
          throw const MemoTranscriptionCancelled();
        }
        final offset = Duration(
          microseconds: chunks[i].start * 1000000 ~/ whisperSampleRate,
        );
        loaded = true;
        final response = await whisper.transcribe(
          transcribeRequest: TranscribeRequest(
            audio: chunks[i].path,
            language: _language,
            maxContext: 0,
            keepModelLoaded: true,
            threads: threads,
          ),
          modelPath: modelPath,
        );
        for (final s in response.segments ?? const []) {
          if (s.text.trim().isEmpty) continue;
          segments.add(
            MemoTranscriptSegment(
              start: offset + s.fromTs,
              end: offset + s.toTs,
              text: s.text.trim(),
            ),
          );
        }
      }
      final transcript = MemoTranscript(
        model: model.modelName,
        language: _language,
        created: DateTime.now(),
        segments: segments,
      );
      await transcript.save(clip.path);
      MemoStore.notifyChanged();
      return transcript;
    } finally {
      if (loaded) unawaited(whisper.releaseModel());
      _jobs.remove(clip.path);
      _cancelled.remove(clip.path);
      notifyListeners();
      await lease?.release();
      for (final name in temp) {
        try {
          await _scope.deleteFile(name);
        } catch (_) {}
      }
    }
  }

  // Static so the isolate closures capture only their arguments.
  static Future<bool> _convert(String source, String target) =>
      Isolate.run(() => convertMemoForWhisper(source, target));

  static Future<List<({String path, int start})>> _split(
    String source,
    String prefix,
  ) => Isolate.run(() => splitWhisperWav(source, prefix));

  @override
  void dispose() {
    unawaited(_scope.cleanTracked());
    super.dispose();
  }
}
