import 'dart:async';
import 'dart:collection';

import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'api/x_api.dart';
import 'config.dart';
import 'models/x_post.dart';

/// Post translations for [XFeedState]: the target language, the translations
/// X sent along or that were fetched, which ones are shown, and the queue
/// that fetches missing ones one at a time when translating automatically.
class XTranslator {
  static const String _translateToKey = 'translate_to';
  static const String _autoKey = 'auto_translate';

  static const List<String> languages = ['en', 'de'];

  final XApi? Function() _api;
  final void Function() _notify;
  final void Function(XApiException e) _onApiError;

  XTranslator(this._api, this._notify, this._onApiError);

  String? _translateTo;
  String _appLanguage = 'en';
  bool _auto = false;

  /// Translations by `postId/language`.
  final Map<String, XTranslation> _fetched = {};

  /// Keys switched on by hand, or off by hand while translating automatically.
  final Set<String> _shown = {};
  final Set<String> _hidden = {};
  final Set<String> _loading = {};

  /// Posts waiting for an automatic translation, fetched one at a time.
  final Queue<XPost> _queue = Queue();
  final Set<String> _attempted = {};
  bool _draining = false;

  /// Set after X limits the rate; automatic fetching stops until reopening.
  bool _paused = false;

  /// The setting; null follows the app's language.
  String? get translateTo => _translateTo;
  String get language => _translateTo ?? _appLanguage;
  bool get auto => _auto;

  Future<void> load() async {
    final db = DatabaseService.instance;
    final id = XFeedTool.config.id;
    final translateTo = await db.getSetting(id, _translateToKey);
    if (languages.contains(translateTo)) _translateTo = translateTo;
    _auto = await db.getSetting(id, _autoKey) == 'true';
    _applyLanguage();
  }

  void setAppLanguage(String code) {
    if (_appLanguage == code) return;
    _appLanguage = code;
    _applyLanguage();
  }

  /// Feeds loaded from now on carry X's translations in [language].
  void _applyLanguage() => _api()?.clientLanguage = language;

  void onApiCreated() => _applyLanguage();

  Future<void> setTranslateTo(String? code) async {
    _translateTo = code;
    _applyLanguage();
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _translateToKey,
      code ?? '',
    );
  }

  Future<void> setAuto(bool value) async {
    _auto = value;
    _hidden.clear();
    _queue.clear();
    _paused = false;
    _notify();
    await DatabaseService.instance.setSetting(
      XFeedTool.config.id,
      _autoKey,
      '$value',
    );
  }

  String _key(XPost post) => '${post.id}/$language';

  XTranslation? _translationOf(XPost post) {
    final fetched = _fetched[_key(post)];
    if (fetched != null) return fetched;
    final inline = post.inlineTranslation;
    return inline != null && inline.language == language ? inline : null;
  }

  /// What the post shows instead of its text, if anything.
  XTranslation? shownOf(XPost post) {
    if (!post.canTranslate) return null;
    final translation = _translationOf(post);
    if (translation == null) return null;
    final key = _key(post);
    final shown = _auto ? !_hidden.contains(key) : _shown.contains(key);
    return shown ? translation : null;
  }

  bool isLoading(XPost post) => _loading.contains(_key(post));

  /// Switches [post] between its text and its translation, fetching it on
  /// first use. False when X has none to give.
  Future<bool> toggle(XPost post) async {
    final key = _key(post);
    if (shownOf(post) != null) {
      _auto ? _hidden.add(key) : _shown.remove(key);
      _notify();
      return true;
    }
    _hidden.remove(key);
    if (!_auto) _shown.add(key);
    if (_translationOf(post) != null) {
      _notify();
      return true;
    }
    final ok = await _fetch(post);
    if (!ok) _shown.remove(key);
    _notify();
    return ok;
  }

  /// Asks for [post]'s translation when translating automatically and X did
  /// not send it along. Requests run one after another, never in parallel.
  void request(XPost post) {
    if (!_auto || _paused || !post.canTranslate) return;
    if (_translationOf(post) != null || !_attempted.add(_key(post))) return;
    _queue.add(post);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && _auto && !_paused) {
        await _fetch(_queue.removeFirst());
        _notify();
      }
    } finally {
      _draining = false;
    }
  }

  Future<bool> _fetch(XPost post) async {
    final api = _api();
    final key = _key(post);
    if (api == null || !_loading.add(key)) return false;
    _notify();
    final target = language;
    try {
      final translation = await api.translatePost(post, target);
      if (translation == null) return false;
      _fetched['${post.id}/$target'] = translation;
      return true;
    } on XApiException catch (e) {
      debugLog('[XTranslator] Translating ${post.id} failed: $e');
      if (e.kind == XApiErrorKind.rateLimited) _paused = true;
      _onApiError(e);
      return false;
    } finally {
      _loading.remove(key);
    }
  }

  void clear() {
    _fetched.clear();
    _shown.clear();
    _hidden.clear();
    _loading.clear();
    _queue.clear();
    _attempted.clear();
    _paused = false;
  }
}
