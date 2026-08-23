import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:re_editor/re_editor.dart';
import 'package:tool_lab/core/shared_file.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/text_editor/config.dart';
import 'package:tool_lab/tools/text_editor/text_editor_languages.dart';
import 'package:tool_lab/tools/text_editor/text_editor_remote_store.dart';

class TextEditorRecentFile {
  final String path;
  final String name;
  final DateTime openedAt;
  final SharedFileOrigin? origin;

  const TextEditorRecentFile({
    required this.path,
    required this.name,
    required this.openedAt,
    this.origin,
  });

  bool get isRemote => origin != null;

  Map<String, Object> toJson() => {
    'path': path,
    'name': name,
    'openedAt': openedAt.millisecondsSinceEpoch,
    if (origin != null) 'origin': origin!.toMap(),
  };

  factory TextEditorRecentFile.fromJson(Map<String, dynamic> json) =>
      TextEditorRecentFile(
        path: json['path'] as String,
        name: json['name'] as String,
        openedAt: DateTime.fromMillisecondsSinceEpoch(json['openedAt'] as int),
        origin: json['origin'] is Map
            ? SharedFileOrigin.fromMap(json['origin'])
            : null,
      );
}

class TextEditorState extends ChangeNotifier {
  static const _recentsKey = 'recent_files';
  static const _wordWrapKey = 'word_wrap';
  static const _highlightKey = 'syntax_highlight';
  static const _fontSizeKey = 'font_size';
  static const _maxRecents = 10;

  /// Files above this size open in read-only-safe refusal rather than risk
  /// OOM from the in-memory document model.
  static const maxEditableBytes = 50 * 1024 * 1024;

  final CodeLineEditingController controller = CodeLineEditingController();
  final CodeScrollController scrollController = CodeScrollController();
  late final CodeFindController findController = CodeFindController(controller);

  /// Owns the local download copies for reopened remote files; cleaned when
  /// the document closes instead of lingering until session end.
  final TempFileScope _remoteScope = TempFileManager.createScope();

  bool _initialized = false;
  bool _dirty = false;
  bool _suppressDirty = false;

  /// Document content as of the last load/save; reference only, dropped once
  /// the document becomes dirty.
  String? _cleanSnapshot;
  String? _filePath;
  String? _fileName;
  SharedFileOrigin? _origin;
  Encoding _encoding = utf8;
  String? _languageKey;
  String? _error;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploading = false;
  List<TextEditorRecentFile> _recentFiles = [];
  bool _wordWrap = false;
  bool _highlightEnabled = true;
  double _fontSize = 14;

  TextEditorState() {
    controller.addListener(_onControllerChanged);
  }

  bool get initialized => _initialized;
  bool get dirty => _dirty;
  String? get filePath => _filePath;
  String? get fileName => _fileName;
  SharedFileOrigin? get origin => _origin;
  bool get isRemote => _origin != null;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploading => _isUploading;
  bool get wordWrap => _wordWrap;
  bool get highlightEnabled => _highlightEnabled;
  double get fontSize => _fontSize;
  String? get languageKey => _languageKey;
  bool get hasHighlightableLanguage => _languageKey != null;
  String get encodingLabel => _encoding == utf8 ? 'UTF-8' : 'Latin-1';
  List<TextEditorRecentFile> get recentFiles => List.unmodifiable(_recentFiles);

  void _onControllerChanged() {
    if (_suppressDirty) return;
    // re_editor fires a notification while its widget mounts (delegate swap)
    // even though nothing changed; real edits never happen mid-build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return;
    }
    if (!_dirty && !_hasContentChanged()) {
      return;
    }
    _dirty = true;
    _cleanSnapshot = null;
    notifyListeners();
  }

  /// Controller notifications also fire for caret moves, selection changes
  /// and toolbar-driven rebuilds, so dirty tracking compares the content
  /// against the last saved/loaded state.
  bool _hasContentChanged() {
    final snapshot = _cleanSnapshot;
    if (snapshot == null) return true;
    return controller.text != snapshot;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final settings = await DatabaseService.instance.getAllSettings(
      TextEditorTool.config.id,
    );
    _wordWrap = settings[_wordWrapKey] == 'true';
    _highlightEnabled = settings[_highlightKey] != 'false';
    final storedSize = double.tryParse(settings[_fontSizeKey] ?? '');
    if (storedSize != null && storedSize >= 10 && storedSize <= 28) {
      _fontSize = storedSize;
    }
    _recentFiles = _decodeRecents(settings[_recentsKey]);
    _initialized = true;
    notifyListeners();
  }

  Future<void> loadSharedFile(SharedFile file, {String? tempPath}) async {
    await _load(
      File(file.path),
      path: file.path,
      name: file.name,
      origin: file.origin,
      recentPath: tempPath ?? file.path,
    );
  }

  Future<void> openLocalPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      _error = 'File not found: $path';
      notifyListeners();
      return;
    }
    await _load(
      file,
      path: path,
      name: path.split(Platform.pathSeparator).last,
    );
  }

  /// Reopens a recent entry. Remote entries are re-downloaded into a fresh
  /// session temp copy; local entries must still exist on disk.
  Future<bool> openRecent(TextEditorRecentFile recent) async {
    if (!recent.isRemote) {
      if (!await File(recent.path).exists()) {
        await removeRecent(recent.path);
        return false;
      }
      await openLocalPath(recent.path);
      return true;
    }
    final tempPath = await _remoteScope.createFile(
      'text_editor_${recent.name}',
    );
    try {
      _isLoading = true;
      notifyListeners();
      await TextEditorRemoteStore.download(
        origin: recent.origin!,
        localPath: tempPath,
      );
      await loadSharedFile(
        SharedFile(
          path: tempPath,
          name: recent.name,
          mimeType: 'text/plain',
          origin: recent.origin,
        ),
        tempPath: tempPath,
      );
      return true;
    } catch (error) {
      errorLog('[TextEditorState] Reopen failed: $error');
      _error = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _load(
    File file, {
    required String path,
    required String name,
    SharedFileOrigin? origin,
    String? recentPath,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final stat = await file.stat();
      if (stat.size > maxEditableBytes) {
        throw Exception('File too large to edit (limit 50 MB).');
      }
      final bytes = await file.readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
        _encoding = utf8;
      } on FormatException {
        text = latin1.decode(bytes);
        _encoding = latin1;
      }
      _filePath = path;
      _fileName = name;
      _origin = origin;
      _languageKey = TextEditorLanguages.keyForFileName(name);
      _suppressDirty = true;
      controller.text = text;
      controller.clearHistory();
      _suppressDirty = false;
      // Snapshot what the editor actually round-trips (it normalizes
      // line endings), not the raw decoded string.
      _cleanSnapshot = controller.text;
      findController.close();
      _dirty = false;
      await _recordRecent(
        TextEditorRecentFile(
          path: recentPath ?? path,
          name: name,
          openedAt: DateTime.now(),
          origin: origin,
        ),
      );
    } catch (error) {
      errorLog('[TextEditorState] Load failed: $error');
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Drops the open document when the tool page goes away, so re-entering
  /// starts at the file chooser instead of restoring the previous file.
  void closeDocument({bool notify = true}) {
    _filePath = null;
    _fileName = null;
    _origin = null;
    _languageKey = null;
    _dirty = false;
    _error = null;
    findController.close();
    _suppressDirty = true;
    controller.text = '';
    controller.clearHistory();
    _suppressDirty = false;
    _cleanSnapshot = controller.text;
    unawaited(_remoteScope.cleanTracked());
    if (notify) notifyListeners();
  }

  /// Starts an unsaved document; saving prompts for a location first.
  void startBlank({
    String name = 'untitled.txt',
    String content = '',
    bool dirty = false,
  }) {
    _filePath = null;
    _fileName = name;
    _origin = null;
    _languageKey = TextEditorLanguages.keyForFileName(name);
    _suppressDirty = true;
    controller.text = content;
    controller.clearHistory();
    _suppressDirty = false;
    _cleanSnapshot = controller.text;
    findController.close();
    _dirty = dirty;
    notifyListeners();
  }

  /// Binds an exported copy as the current document (Save As flow).
  Future<void> adoptSavedPath(String path, String name) async {
    _filePath = path;
    _fileName = name;
    _origin = null;
    _languageKey = TextEditorLanguages.keyForFileName(name);
    _dirty = false;
    _cleanSnapshot = controller.text;
    await _recordRecent(
      TextEditorRecentFile(path: path, name: name, openedAt: DateTime.now()),
    );
  }

  Future<bool> save() async {
    if (_filePath == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final text = controller.text;
      final bytes = Uint8List.fromList(_encoding.encode(text));
      await File(_filePath!).writeAsBytes(bytes, flush: true);
      if (_origin != null) {
        _isUploading = true;
        notifyListeners();
        try {
          await TextEditorRemoteStore.upload(
            origin: _origin!,
            localPath: _filePath!,
          );
        } catch (error) {
          errorLog('[TextEditorState] Upload failed: $error');
          _error = error.toString().replaceFirst('Exception: ', '');
          notifyListeners();
          return false;
        }
      }
      _dirty = false;
      _cleanSnapshot = text;
      await _touchRecent(_filePath!, _fileName!, _origin);
      return true;
    } catch (error) {
      errorLog('[TextEditorState] Save failed: $error');
      _error = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isUploading = false;
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> setWordWrap(bool value) async {
    _wordWrap = value;
    await DatabaseService.instance.setSetting(
      TextEditorTool.config.id,
      _wordWrapKey,
      value.toString(),
    );
    notifyListeners();
  }

  Future<void> setHighlightEnabled(bool value) async {
    _highlightEnabled = value;
    await DatabaseService.instance.setSetting(
      TextEditorTool.config.id,
      _highlightKey,
      value.toString(),
    );
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value.clamp(10.0, 28.0);
    await DatabaseService.instance.setSetting(
      TextEditorTool.config.id,
      _fontSizeKey,
      _fontSize.toString(),
    );
    notifyListeners();
  }

  Future<void> _recordRecent(TextEditorRecentFile entry) async {
    _recentFiles = [
      entry,
      ..._recentFiles.where((item) => item.path != entry.path),
    ].take(_maxRecents).toList();
    await DatabaseService.instance.setSetting(
      TextEditorTool.config.id,
      _recentsKey,
      jsonEncode(_recentFiles.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _touchRecent(
    String path,
    String name,
    SharedFileOrigin? origin,
  ) {
    return _recordRecent(
      TextEditorRecentFile(
        path: path,
        name: name,
        openedAt: DateTime.now(),
        origin: origin,
      ),
    );
  }

  Future<void> removeRecent(String path) async {
    _recentFiles = _recentFiles.where((item) => item.path != path).toList();
    await DatabaseService.instance.setSetting(
      TextEditorTool.config.id,
      _recentsKey,
      jsonEncode(_recentFiles.map((item) => item.toJson()).toList()),
    );
    notifyListeners();
  }

  List<TextEditorRecentFile> _decodeRecents(String? source) {
    if (source == null) return [];
    try {
      return (jsonDecode(source) as List<dynamic>)
          .map(
            (item) =>
                TextEditorRecentFile.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    findController.dispose();
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
