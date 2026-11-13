import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/text_to_speech_service.dart';
import 'package:tool_lab/services/translation/translation_service.dart';

import 'config.dart';

enum TranslatorStatus {
  idle,
  detecting,
  downloading,
  translating,
  undetermined,
  failed,
}

class TranslatorState extends ChangeNotifier {
  static const _logPrefix = '[TranslatorState]';
  static const _kSource = 'source';
  static const _kTarget = 'target';
  static const _auto = 'auto';
  static const _typingDelay = Duration(milliseconds: 500);

  final TranslationService _service = TranslationService.instance;

  String _input = '';
  String _output = '';
  TranslateLanguage? _source;
  TranslateLanguage? _detected;
  TranslateLanguage? _target;
  TranslatorStatus _status = TranslatorStatus.idle;
  TranslateLanguage? _downloading;
  String? _error;
  bool _speaking = false;
  bool _loaded = false;
  Timer? _debounce;
  int _run = 0;

  Map<TranslateLanguage, bool>? _models;
  final Set<TranslateLanguage> _modelsBusy = {};

  /// UI language, used for the default target.
  String uiLanguageCode = 'en';

  String get input => _input;
  String get output => _output;

  /// Null means detect automatically.
  TranslateLanguage? get source => _source;
  TranslateLanguage? get detected => _detected;
  TranslateLanguage? get effectiveSource => _source ?? _detected;
  TranslateLanguage get target =>
      _target ??
      TranslationService.defaultTarget(uiLanguageCode, effectiveSource);
  TranslatorStatus get status => _status;
  TranslateLanguage? get downloading => _downloading;
  String? get error => _error;
  bool get speaking => _speaking;
  bool get busy =>
      _status == TranslatorStatus.detecting ||
      _status == TranslatorStatus.downloading ||
      _status == TranslatorStatus.translating;
  bool get canSwap => effectiveSource != null && !busy;

  /// Downloaded state per language; null until [refreshModels] ran.
  Map<TranslateLanguage, bool>? get models => _models;
  bool isModelBusy(TranslateLanguage language) =>
      _modelsBusy.contains(language);

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    final db = DatabaseService.instance;
    final id = TranslatorTool.config.id;
    final source = await db.getSetting(id, _kSource);
    final target = await db.getSetting(id, _kTarget);
    _source = source == null || source == _auto
        ? null
        : TranslationService.languageFor(source);
    _target = TranslationService.languageFor(target);
    notifyListeners();
  }

  /// Typed text waits for a pause; pasted, dictated or scanned text does not.
  void setInput(String text, {bool immediate = false}) {
    if (text == _input) return;
    _input = text;
    _schedule(immediate: immediate);
  }

  void setSource(TranslateLanguage? language) {
    if (language == _source) return;
    _source = language;
    if (language != null) _detected = null;
    unawaited(_save(_kSource, language?.bcpCode ?? _auto));
    _schedule(immediate: true);
  }

  void setTarget(TranslateLanguage language) {
    if (language == _target) return;
    _target = language;
    unawaited(_save(_kTarget, language.bcpCode));
    _schedule(immediate: true);
  }

  /// Turns the translation around: the result becomes the input.
  void swap() {
    final from = effectiveSource;
    if (from == null || busy) return;
    final to = target;
    if (_output.isNotEmpty) _input = _output;
    // Automatic detection stays on and finds the new input's language.
    if (_source != null) {
      _source = to;
      unawaited(_save(_kSource, to.bcpCode));
    }
    _detected = null;
    _target = from;
    unawaited(_save(_kTarget, from.bcpCode));
    _schedule(immediate: true);
  }

  void clear() {
    _debounce?.cancel();
    _run++;
    _input = '';
    _output = '';
    _detected = null;
    _error = null;
    _downloading = null;
    _status = TranslatorStatus.idle;
    notifyListeners();
  }

  Future<void> loadSharedData(SharedData data) async {
    final text = data.text;
    if (text != null) {
      setInput(text, immediate: true);
      return;
    }
    final file = data.firstFile;
    if (file == null) return;
    try {
      setInput(await File(file.path).readAsString(), immediate: true);
    } catch (e) {
      errorLog('$_logPrefix shared file unreadable: $e');
    }
  }

  void _schedule({required bool immediate}) {
    _debounce?.cancel();
    final run = ++_run;
    if (_input.trim().isEmpty) {
      _output = '';
      _detected = null;
      _error = null;
      _downloading = null;
      _status = TranslatorStatus.idle;
      notifyListeners();
      return;
    }
    notifyListeners();
    if (immediate) {
      unawaited(_translate(run));
    } else {
      _debounce = Timer(_typingDelay, () => _translate(run));
    }
  }

  void _setStatus(TranslatorStatus status, int run) {
    if (run != _run) return;
    _status = status;
    notifyListeners();
  }

  Future<void> _translate(int run) async {
    final text = _input;
    _error = null;
    try {
      var source = _source;
      if (source == null) {
        _setStatus(TranslatorStatus.detecting, run);
        source = TranslationService.languageFor(
          await _service.identifyLanguage(text),
        );
        if (run != _run) return;
        _detected = source;
        if (source == null) {
          _output = '';
          _setStatus(TranslatorStatus.undetermined, run);
          return;
        }
      }
      final target = this.target;
      if (source == target) {
        _output = text;
        _setStatus(TranslatorStatus.idle, run);
        return;
      }
      for (final language in {source, target}) {
        if (await _service.isModelReady(language)) continue;
        if (run != _run) return;
        _downloading = language;
        _setStatus(TranslatorStatus.downloading, run);
        final ok = await _service.downloadModel(language);
        if (!ok) throw Exception('Model download failed: ${language.bcpCode}');
        if (_models != null) _models![language] = true;
      }
      if (run != _run) return;
      _downloading = null;
      _setStatus(TranslatorStatus.translating, run);
      final output = await _service.translate(
        text,
        source: source,
        target: target,
      );
      if (run != _run) return;
      _output = output;
      _setStatus(TranslatorStatus.idle, run);
    } catch (e) {
      if (run != _run) return;
      errorLog('$_logPrefix translation failed: $e');
      _downloading = null;
      _output = '';
      _error = e.toString();
      _setStatus(TranslatorStatus.failed, run);
    }
  }

  /// Reads the translation aloud, or stops it. Returns the error, if any.
  Future<TextToSpeechError?> toggleSpeech() async {
    if (_speaking) {
      await TextToSpeechService.stop();
      return null;
    }
    if (_output.trim().isEmpty) return null;
    _speaking = true;
    notifyListeners();
    try {
      await TextToSpeechService.speak(_output, language: target.bcpCode);
      return null;
    } on TextToSpeechException catch (e) {
      return e.error;
    } catch (e) {
      errorLog('$_logPrefix speech failed: $e');
      return TextToSpeechError.unavailable;
    } finally {
      _speaking = false;
      notifyListeners();
    }
  }

  Future<void> refreshModels() async {
    final models = <TranslateLanguage, bool>{};
    for (final language in TranslationService.languages) {
      models[language] = await _service.isModelReady(language);
    }
    _models = models;
    notifyListeners();
  }

  Future<bool> downloadModel(TranslateLanguage language) =>
      _changeModel(language, () => _service.downloadModel(language), true);

  Future<bool> deleteModel(TranslateLanguage language) =>
      _changeModel(language, () => _service.deleteModel(language), false);

  Future<bool> _changeModel(
    TranslateLanguage language,
    Future<bool> Function() change,
    bool downloaded,
  ) async {
    if (!_modelsBusy.add(language)) return false;
    notifyListeners();
    try {
      final ok = await change();
      if (ok) _models?[language] = downloaded;
      return ok;
    } catch (e) {
      errorLog('$_logPrefix model change failed for ${language.bcpCode}: $e');
      return false;
    } finally {
      _modelsBusy.remove(language);
      notifyListeners();
    }
  }

  Future<void> _save(String key, String value) =>
      DatabaseService.instance.setSetting(TranslatorTool.config.id, key, value);

  /// Drops the texts and the speech engine when the tool closes.
  void release() {
    if (_speaking) unawaited(TextToSpeechService.stop());
    if (TextToSpeechService.isSupported) {
      unawaited(TextToSpeechService.release());
    }
    _models = null;
    clear();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
