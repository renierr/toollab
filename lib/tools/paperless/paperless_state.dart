import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/database_service.dart';

import 'config.dart';
import 'models/paperless_document.dart';
import 'models/paperless_filter.dart';
import 'models/paperless_label.dart';
import 'models/paperless_statistics.dart';
import 'models/paperless_task.dart';
import 'models/paperless_upload.dart';
import 'paperless_api.dart';

class PaperlessState extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _serverUrlKey = 'server_url';
  static const _usernameKey = 'username';
  static const _tokenStorageKey = 'paperless_api_token';
  static const _thumbnailCacheSize = 200;
  static const _taskPollInterval = Duration(seconds: 2);
  static const _taskPollAttempts = 90;

  String get _toolId => PaperlessTool.config.id;

  bool _disposed = false;
  Future<void>? _loading;
  bool _isLoaded = false;
  PaperlessApi? _api;
  String? _savedServerUrl;
  String? _username;

  /// Bumped on every connection change so late responses for the previous
  /// server are dropped.
  int _connection = 0;

  final Map<int, PaperlessLabel> _tags = {};
  final Map<int, PaperlessLabel> _correspondents = {};
  final Map<int, PaperlessLabel> _documentTypes = {};

  final List<PaperlessDocument> _documents = [];
  PaperlessFilter _filter = const PaperlessFilter();
  int _documentCount = 0;
  int _page = 0;
  bool _hasMore = false;
  bool _isLoadingDocuments = false;
  bool _isLoadingMore = false;
  Object? _documentsError;
  Object? _loadMoreError;
  int _documentsRequest = 0;

  PaperlessStatistics? _statistics;
  bool _isLoadingStatistics = false;
  Object? _statisticsError;

  final LinkedHashMap<int, Uint8List> _thumbnails = LinkedHashMap();
  final Map<int, Future<Uint8List?>> _thumbnailRequests = {};

  final List<PaperlessUpload> _uploads = [];
  PaperlessUploadOptions _uploadOptions = const PaperlessUploadOptions();
  bool _isUploading = false;
  int _uploadSeq = 0;

  bool get isLoaded => _isLoaded;
  bool get isConfigured => _api != null;
  PaperlessApi? get api => _api;
  String get serverUrl => _api?.baseUri.toString() ?? _savedServerUrl ?? '';
  String? get username => _username;

  List<PaperlessLabel> get tags => _sorted(_tags);
  List<PaperlessLabel> get correspondents => _sorted(_correspondents);
  List<PaperlessLabel> get documentTypes => _sorted(_documentTypes);
  PaperlessLabel? tag(int id) => _tags[id];
  PaperlessLabel? correspondent(int? id) =>
      id == null ? null : _correspondents[id];
  PaperlessLabel? documentType(int? id) =>
      id == null ? null : _documentTypes[id];

  List<PaperlessDocument> get documents => List.unmodifiable(_documents);
  PaperlessFilter get filter => _filter;
  int get documentCount => _documentCount;
  bool get hasMoreDocuments => _hasMore;
  bool get isLoadingDocuments => _isLoadingDocuments;
  bool get isLoadingMore => _isLoadingMore;
  Object? get documentsError => _documentsError;
  Object? get loadMoreError => _loadMoreError;

  PaperlessStatistics? get statistics => _statistics;
  bool get isLoadingStatistics => _isLoadingStatistics;
  Object? get statisticsError => _statisticsError;

  List<PaperlessUpload> get uploads => List.unmodifiable(_uploads);
  PaperlessUploadOptions get uploadOptions => _uploadOptions;
  bool get isUploading => _isUploading;
  int get pendingUploadCount =>
      _uploads.where((u) => u.status == PaperlessUploadStatus.pending).length;
  bool get hasFinishedUploads => _uploads.any(
    (u) => u.isFinished || u.status == PaperlessUploadStatus.failed,
  );

  static List<PaperlessLabel> _sorted(Map<int, PaperlessLabel> labels) =>
      labels.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final settings = await DatabaseService.instance.getAllSettings(_toolId);
    String? token;
    try {
      token = await _secureStorage.read(key: _tokenStorageKey);
    } catch (e) {
      errorLog('[Paperless] Reading the API token failed: $e');
    }
    final url = settings[_serverUrlKey];
    final baseUri = url == null ? null : PaperlessApi.parseBaseUri(url);
    _savedServerUrl = url;
    _username = settings[_usernameKey];
    if (baseUri != null && token != null && token.isNotEmpty) {
      _api = PaperlessApi(baseUri: baseUri, token: token);
    }
    _isLoaded = true;
    _notify();
  }

  /// Saves without contacting the server, so a connection can be set up while
  /// the server is out of reach. A null [token] keeps the stored one.
  Future<void> saveConnection({
    required Uri baseUri,
    String? token,
    String? username,
  }) async {
    await ensureLoaded();
    final effectiveToken = token ?? _api?.token;
    if (effectiveToken == null || effectiveToken.isEmpty) {
      throw const PaperlessException(PaperlessErrorKind.unauthorized);
    }
    await DatabaseService.instance.setSetting(
      _toolId,
      _serverUrlKey,
      baseUri.toString(),
    );
    if (username == null) {
      await DatabaseService.instance.deleteSetting(_toolId, _usernameKey);
    } else {
      await DatabaseService.instance.setSetting(
        _toolId,
        _usernameKey,
        username,
      );
    }
    if (token != null) {
      await _secureStorage.write(key: _tokenStorageKey, value: token);
    }
    _savedServerUrl = baseUri.toString();
    _username = username;
    _api = PaperlessApi(baseUri: baseUri, token: effectiveToken);
    _resetServerData();
    _notify();
  }

  /// The password only buys a token; it is never stored.
  Future<void> signIn({
    required Uri baseUri,
    required String username,
    required String password,
  }) async {
    final token = await PaperlessApi.obtainToken(baseUri, username, password);
    await saveConnection(baseUri: baseUri, token: token, username: username);
  }

  Future<PaperlessServerInfo> testConnection() {
    final api = _api;
    if (api == null) {
      return Future.error(
        const PaperlessException(PaperlessErrorKind.unauthorized),
      );
    }
    return api.serverInfo();
  }

  Future<void> disconnect() async {
    try {
      await _secureStorage.delete(key: _tokenStorageKey);
    } catch (e) {
      errorLog('[Paperless] Deleting the API token failed: $e');
    }
    await DatabaseService.instance.deleteSetting(_toolId, _usernameKey);
    _api = null;
    _username = null;
    _resetServerData();
    _notify();
  }

  void _resetServerData() {
    _connection++;
    _documentsRequest++;
    _tags.clear();
    _correspondents.clear();
    _documentTypes.clear();
    _documents.clear();
    _documentCount = 0;
    _page = 0;
    _hasMore = false;
    _isLoadingDocuments = false;
    _isLoadingMore = false;
    _documentsError = null;
    _loadMoreError = null;
    _statistics = null;
    _statisticsError = null;
    _isLoadingStatistics = false;
    _thumbnails.clear();
    _thumbnailRequests.clear();
    _uploadOptions = const PaperlessUploadOptions();
  }

  Future<void> refreshAll() async {
    await ensureLoaded();
    if (_api == null) return;
    await Future.wait([loadLabels(), refreshDocuments(), refreshStatistics()]);
  }

  Future<void> loadLabels() async {
    final api = _api;
    if (api == null) return;
    final connection = _connection;
    try {
      final results = await Future.wait([
        api.tags(),
        api.correspondents(),
        api.documentTypes(),
      ]);
      if (connection != _connection) return;
      _replaceLabels(_tags, results[0]);
      _replaceLabels(_correspondents, results[1]);
      _replaceLabels(_documentTypes, results[2]);
      _notify();
    } catch (e) {
      errorLog('[Paperless] Loading labels failed: $e');
    }
  }

  static void _replaceLabels(
    Map<int, PaperlessLabel> target,
    List<PaperlessLabel> labels,
  ) {
    target
      ..clear()
      ..addEntries(labels.map((l) => MapEntry(l.id, l)));
  }

  void setFilter(PaperlessFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    refreshDocuments();
  }

  Future<void> refreshDocuments() async {
    final api = _api;
    if (api == null) return;
    final request = ++_documentsRequest;
    _isLoadingDocuments = true;
    _isLoadingMore = false;
    _documentsError = null;
    _loadMoreError = null;
    _notify();
    try {
      final result = await api.documents(filter: _filter, page: 1);
      if (request != _documentsRequest) return;
      _documents
        ..clear()
        ..addAll(result.items);
      _documentCount = result.count;
      _page = 1;
      _hasMore = result.hasNext;
    } catch (e) {
      if (request != _documentsRequest) return;
      errorLog('[Paperless] Loading documents failed: $e');
      _documentsError = e;
    }
    _isLoadingDocuments = false;
    _notify();
  }

  Future<void> loadMoreDocuments() async {
    final api = _api;
    if (api == null || !_hasMore || _isLoadingDocuments || _isLoadingMore) {
      return;
    }
    final request = _documentsRequest;
    _isLoadingMore = true;
    _loadMoreError = null;
    _notify();
    try {
      final result = await api.documents(filter: _filter, page: _page + 1);
      if (request != _documentsRequest) return;
      final known = _documents.map((d) => d.id).toSet();
      _documents.addAll(result.items.where((d) => !known.contains(d.id)));
      _documentCount = result.count;
      _page++;
      _hasMore = result.hasNext;
    } catch (e) {
      if (request != _documentsRequest) return;
      errorLog('[Paperless] Loading more documents failed: $e');
      _loadMoreError = e;
    }
    _isLoadingMore = false;
    _notify();
  }

  Future<void> refreshStatistics() async {
    final api = _api;
    if (api == null) return;
    final connection = _connection;
    _isLoadingStatistics = true;
    _statisticsError = null;
    _notify();
    try {
      final stats = await api.statistics();
      if (connection != _connection) return;
      _statistics = stats;
    } catch (e) {
      if (connection != _connection) return;
      errorLog('[Paperless] Loading statistics failed: $e');
      _statisticsError = e;
    }
    _isLoadingStatistics = false;
    _notify();
  }

  Uint8List? cachedThumbnail(int id) => _thumbnails[id];

  Future<Uint8List?> thumbnail(int id) {
    final cached = _thumbnails.remove(id);
    if (cached != null) {
      _thumbnails[id] = cached;
      return SynchronousFuture(cached);
    }
    return _thumbnailRequests[id] ??= _fetchThumbnail(id);
  }

  Future<Uint8List?> _fetchThumbnail(int id) async {
    final api = _api;
    if (api == null) return null;
    final connection = _connection;
    try {
      final bytes = await api.thumbnail(id);
      if (connection != _connection) return null;
      _thumbnails[id] = bytes;
      if (_thumbnails.length > _thumbnailCacheSize) {
        _thumbnails.remove(_thumbnails.keys.first);
      }
      return bytes;
    } catch (e) {
      debugLog('[Paperless] Thumbnail $id failed: $e');
      return null;
    } finally {
      if (connection == _connection) _thumbnailRequests.remove(id);
    }
  }

  void addUploadFiles(Iterable<({String path, String name})> files) {
    var added = false;
    for (final file in files) {
      // The same share can arrive twice: once as route extra, once on the
      // sharing stream.
      final duplicate = _uploads.any(
        (u) => u.path == file.path && !u.isFinished,
      );
      if (duplicate) continue;
      _uploads.add(
        PaperlessUpload(
          id: 'upload-${_uploadSeq++}',
          path: file.path,
          fileName: file.name.isEmpty ? p.basename(file.path) : file.name,
        ),
      );
      added = true;
    }
    if (added) _notify();
  }

  void renameUpload(String id, String title) {
    final trimmed = title.trim();
    _updateUpload(
      id,
      (u) => u.copyWith(title: () => trimmed.isEmpty ? null : trimmed),
    );
  }

  void removeUpload(String id) {
    _uploads.removeWhere((u) => u.id == id && !u.isActive);
    _notify();
  }

  void clearFinishedUploads() {
    _uploads.removeWhere(
      (u) => u.isFinished || u.status == PaperlessUploadStatus.failed,
    );
    _notify();
  }

  void setUploadOptions(PaperlessUploadOptions options) {
    _uploadOptions = options;
    _notify();
  }

  void retryUpload(String id) {
    _updateUpload(
      id,
      (u) => u.copyWith(
        status: PaperlessUploadStatus.pending,
        progress: () => null,
        error: () => null,
      ),
    );
    startUploads();
  }

  Future<void> startUploads() async {
    final api = _api;
    if (api == null || _isUploading) return;
    _isUploading = true;
    _notify();
    final options = _uploadOptions;
    try {
      while (!_disposed && api == _api) {
        final next = _uploads
            .where((u) => u.status == PaperlessUploadStatus.pending)
            .firstOrNull;
        if (next == null) break;
        await _upload(next, api, options);
      }
    } finally {
      _isUploading = false;
      _notify();
    }
  }

  Future<void> _upload(
    PaperlessUpload upload,
    PaperlessApi api,
    PaperlessUploadOptions options,
  ) async {
    _updateUpload(
      upload.id,
      (u) => u.copyWith(
        status: PaperlessUploadStatus.uploading,
        progress: () => 0,
        error: () => null,
      ),
    );
    var lastReported = 0.0;
    try {
      final taskId = await api.upload(
        path: upload.path,
        fileName: upload.fileName,
        title: upload.title,
        correspondentId: options.correspondentId,
        documentTypeId: options.documentTypeId,
        tagIds: options.tagIds,
        onProgress: (sent, total) {
          if (total <= 0) return;
          final progress = sent / total;
          if (progress - lastReported < 0.02 && sent != total) return;
          lastReported = progress;
          _updateUpload(upload.id, (u) => u.copyWith(progress: () => progress));
        },
      );
      debugLog('[Paperless] Uploaded ${upload.fileName}, task: $taskId');
      if (taskId == null) {
        _updateUpload(
          upload.id,
          (u) => u.copyWith(
            status: PaperlessUploadStatus.queued,
            progress: () => null,
          ),
        );
        return;
      }
      _updateUpload(
        upload.id,
        (u) => u.copyWith(
          status: PaperlessUploadStatus.processing,
          progress: () => null,
          taskId: taskId,
        ),
      );
      unawaited(_followTask(upload.id, api, taskId));
    } catch (e) {
      errorLog('[Paperless] Upload of ${upload.fileName} failed: $e');
      _updateUpload(
        upload.id,
        (u) => u.copyWith(
          status: PaperlessUploadStatus.failed,
          progress: () => null,
          error: () => e,
        ),
      );
    }
  }

  Future<void> _followTask(
    String uploadId,
    PaperlessApi api,
    String taskId,
  ) async {
    var failures = 0;
    for (var attempt = 0; attempt < _taskPollAttempts; attempt++) {
      await Future<void>.delayed(_taskPollInterval);
      if (_disposed || api != _api || !_uploads.any((u) => u.id == uploadId)) {
        return;
      }
      final PaperlessTask? polled;
      try {
        polled = await api.task(taskId);
      } catch (e) {
        if (++failures >= 5) break;
        continue;
      }
      if (polled == null) break;
      final task = polled;
      switch (task.status) {
        case PaperlessTaskStatus.success:
          _updateUpload(
            uploadId,
            (u) => u.copyWith(
              status: PaperlessUploadStatus.done,
              documentId: task.documentId,
            ),
          );
          refreshDocuments();
          refreshStatistics();
          return;
        case PaperlessTaskStatus.failure:
          _updateUpload(
            uploadId,
            (u) => u.copyWith(
              status: PaperlessUploadStatus.failed,
              error: () => PaperlessException(
                PaperlessErrorKind.rejected,
                task.result ?? '',
              ),
            ),
          );
          return;
        case PaperlessTaskStatus.pending:
        case PaperlessTaskStatus.running:
          continue;
      }
    }
    _updateUpload(
      uploadId,
      (u) => u.status == PaperlessUploadStatus.processing
          ? u.copyWith(status: PaperlessUploadStatus.queued)
          : u,
    );
  }

  void _updateUpload(String id, PaperlessUpload Function(PaperlessUpload) fn) {
    final index = _uploads.indexWhere((u) => u.id == id);
    if (index < 0) return;
    _uploads[index] = fn(_uploads[index]);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
