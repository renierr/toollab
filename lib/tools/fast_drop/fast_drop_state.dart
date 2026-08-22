import 'package:flutter/foundation.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/helpers/format_helper.dart';
import 'package:tool_lab/services/background_work_lease.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'fast_drop_model.dart';
import 'fast_drop_service.dart';
import 'config.dart';

class FastDropState extends ChangeNotifier {
  static const bool _reportTransferProgress = true;
  static const String _kRetention = 'retention';
  List<FastDropItem> _fastDrops = [];
  bool _isLoadingFastDrops = false;
  bool _isUploadingFastDrop = false;
  bool _isDownloadingFastDrop = false;
  (int sent, int total)? _fastDropUploadProgress;
  (int received, int total)? _fastDropDownloadProgress;
  bool _cancelUploadRequested = false;
  bool _cancelDownloadRequested = false;
  String? _fastDropError;
  bool _isServerAvailable = true;
  int _lastUploadProgressNotifyMs = 0;
  int _lastDownloadProgressNotifyMs = 0;
  DateTime? _transferStartedAt;
  final ValueNotifier<int> _transferProgressRevision = ValueNotifier(0);
  String _syncServerUrl = '';
  String _retention = '24';

  String get retention => _retention;

  Future<void> loadRetention() async {
    final val = await DatabaseService.instance.getSetting(
      FastDropTool.config.id,
      _kRetention,
    );
    if (val != null && val.isNotEmpty) {
      _retention = val;
      notifyListeners();
    }
  }

  void setRetention(String val) {
    _retention = val;
    notifyListeners();
    DatabaseService.instance.setSetting(
      FastDropTool.config.id,
      _kRetention,
      val,
    );
  }

  List<FastDropItem> get fastDrops => _fastDrops;
  bool get isLoadingFastDrops => _isLoadingFastDrops;
  bool get isUploadingFastDrop => _isUploadingFastDrop;
  bool get isDownloadingFastDrop => _isDownloadingFastDrop;
  (int sent, int total)? get fastDropUploadProgress => _fastDropUploadProgress;
  (int received, int total)? get fastDropDownloadProgress =>
      _fastDropDownloadProgress;
  String? get fastDropError => _fastDropError;
  bool get isServerAvailable => _isServerAvailable;
  DateTime? get transferStartedAt => _transferStartedAt;
  ValueListenable<int> get transferProgressRevision =>
      _transferProgressRevision;

  Future<String> _loadServerUrl() async {
    _syncServerUrl =
        (await DatabaseService.instance.getSetting(
          '_app',
          'sync_server_url',
        )) ??
        '';
    return _syncServerUrl;
  }

  /// Notification strings come from the caller so they follow app locale.
  static const _notificationTitleFallback = 'Fast Drop transfer';

  static String _progressText(
    String verb,
    String name,
    int current,
    int total,
  ) {
    final size = total > 0
        ? '${FormatHelper.fileSize(current)} / ${FormatHelper.fileSize(total)}'
        : FormatHelper.fileSize(current);
    return '$verb $name — $size';
  }

  Future<bool> _isSyncEnabled() async {
    final val = await DatabaseService.instance.getSetting(
      '_app',
      'sync_enabled',
    );
    return val == 'true';
  }

  Future<void> loadFastDrops() async {
    final syncEnabled = await _isSyncEnabled();
    await _loadServerUrl();

    if (!syncEnabled) {
      _fastDropError = 'Cloud sync is disabled.';
      _fastDrops = [];
      _isServerAvailable = false;
      notifyListeners();
      return;
    }

    if (_syncServerUrl.isEmpty) {
      _fastDropError =
          'Sync Server URL is not configured. Please configure it in settings.';
      _fastDrops = [];
      _isServerAvailable = false;
      notifyListeners();
      return;
    }

    _isLoadingFastDrops = true;
    _fastDropError = null;
    notifyListeners();

    try {
      final available = await SyncService.isBackendAvailable(_syncServerUrl);
      _isServerAvailable = available;
      if (!available) {
        _fastDropError = 'Sync server is offline or unreachable.';
        _fastDrops = [];
      } else {
        _fastDrops = await FastDropService.fetchDrops(_syncServerUrl);
      }
    } catch (e) {
      _isServerAvailable = false;
      _fastDropError = e.toString().replaceAll('Exception: ', '');
      _fastDrops = [];
      errorLog('[FastDropState] Failed to load Fast Drops: $e');
    } finally {
      _isLoadingFastDrops = false;
      notifyListeners();
    }
  }

  void cancelUploadFastDrop() {
    _cancelUploadRequested = true;
  }

  void cancelDownloadFastDrop() {
    _cancelDownloadRequested = true;
  }

  Future<void> uploadFastDrop({
    required String filename,
    required String filePath,
    required String retention,
    required String source,
    required String mimeType,
    String? notificationTitle,
    String? uploadingLabel,
  }) async {
    await _loadServerUrl();
    final syncEnabled = await _isSyncEnabled();
    if (!syncEnabled) {
      throw Exception('Cloud sync is disabled.');
    }
    if (_syncServerUrl.isEmpty) {
      throw Exception('Sync Server URL is not configured');
    }
    if (!_isServerAvailable) {
      throw Exception('Sync server is unreachable.');
    }

    _cancelUploadRequested = false;
    _isUploadingFastDrop = true;
    _fastDropUploadProgress = null;
    _lastUploadProgressNotifyMs = 0;
    _transferStartedAt = DateTime.now();
    _transferProgressRevision.value++;
    notifyListeners();

    final work = await BackgroundWorkLease.acquire(
      title: notificationTitle ?? _notificationTitleFallback,
      text: _progressText(uploadingLabel ?? 'Uploading', filename, 0, 0),
      logPrefix: 'FastDropState',
    );
    try {
      await FastDropService.uploadDrop(
        baseUrl: _syncServerUrl,
        filename: filename,
        filePath: filePath,
        retention: retention,
        source: source,
        mimeType: mimeType,
        onProgress: _reportTransferProgress
            ? (sent, total) {
                _fastDropUploadProgress = (sent, total);
                work.update(
                  _progressText(
                    uploadingLabel ?? 'Uploading',
                    filename,
                    sent,
                    total,
                  ),
                );
                if (_shouldNotifyTransferProgress(
                  current: sent,
                  total: total,
                  isUpload: true,
                )) {
                  _transferProgressRevision.value++;
                }
              }
            : null,
        isCancelled: () => _cancelUploadRequested,
      );
      await loadFastDrops();
    } finally {
      await work.release();
      _cancelUploadRequested = false;
      _isUploadingFastDrop = false;
      _fastDropUploadProgress = null;
      _transferStartedAt = null;
      _transferProgressRevision.value++;
      notifyListeners();
    }
  }

  Future<void> deleteFastDrop(String id) async {
    await _loadServerUrl();
    if (_syncServerUrl.isEmpty || !_isServerAvailable) return;
    try {
      await FastDropService.deleteDrop(_syncServerUrl, id);
      await loadFastDrops();
    } catch (e) {
      errorLog('[FastDropState] Failed to delete Fast Drop: $e');
      rethrow;
    }
  }

  Future<void> keepFastDrop(String id) async {
    await _loadServerUrl();
    if (_syncServerUrl.isEmpty || !_isServerAvailable) return;
    try {
      await FastDropService.keepDrop(_syncServerUrl, id);
      await loadFastDrops();
    } catch (e) {
      errorLog('[FastDropState] Failed to update Fast Drop retention: $e');
      rethrow;
    }
  }

  Future<void> updateFastDropDescription(String id, String description) async {
    await _loadServerUrl();
    if (_syncServerUrl.isEmpty || !_isServerAvailable) return;
    try {
      await FastDropService.updateDescription(_syncServerUrl, id, description);
      await loadFastDrops();
    } catch (e) {
      errorLog('[FastDropState] Failed to update Fast Drop description: $e');
      rethrow;
    }
  }

  Future<void> updateFastDropRetention(String id, String retention) async {
    await _loadServerUrl();
    if (_syncServerUrl.isEmpty || !_isServerAvailable) return;
    try {
      await FastDropService.updateRetention(_syncServerUrl, id, retention);
      await loadFastDrops();
    } catch (e) {
      errorLog('[FastDropState] Failed to update Fast Drop retention: $e');
      rethrow;
    }
  }

  Future<String> downloadFastDropToFile({
    required String id,
    required String outputPath,
    int? knownSize,
    String? notificationTitle,
    String? downloadingLabel,
  }) async {
    await _loadServerUrl();
    final syncEnabled = await _isSyncEnabled();
    if (!syncEnabled) {
      throw Exception('Cloud sync is disabled.');
    }
    if (_syncServerUrl.isEmpty) {
      throw Exception('Sync Server URL is not configured');
    }
    if (!_isServerAvailable) {
      throw Exception('Sync server is unreachable.');
    }

    int? size = knownSize;
    var name = outputPath.split(RegExp(r'[/\\]')).last;
    for (final item in _fastDrops) {
      if (item.id == id) {
        size ??= item.size;
        name = item.filename;
        break;
      }
    }

    _cancelDownloadRequested = false;
    _isDownloadingFastDrop = true;
    _fastDropDownloadProgress = null;
    _lastDownloadProgressNotifyMs = 0;
    _transferStartedAt = DateTime.now();
    _transferProgressRevision.value++;
    notifyListeners();

    final work = await BackgroundWorkLease.acquire(
      title: notificationTitle ?? _notificationTitleFallback,
      text: _progressText(
        downloadingLabel ?? 'Downloading',
        name,
        0,
        size ?? 0,
      ),
      logPrefix: 'FastDropState',
    );
    try {
      return await FastDropService.downloadDropToFile(
        baseUrl: _syncServerUrl,
        id: id,
        outputPath: outputPath,
        onProgress: _reportTransferProgress
            ? (received, total) {
                final effectiveTotal = total > 0 ? total : (size ?? -1);
                _fastDropDownloadProgress = (received, effectiveTotal);
                work.update(
                  _progressText(
                    downloadingLabel ?? 'Downloading',
                    name,
                    received,
                    effectiveTotal > 0 ? effectiveTotal : 0,
                  ),
                );
                if (_shouldNotifyTransferProgress(
                  current: received,
                  total: effectiveTotal,
                  isUpload: false,
                )) {
                  _transferProgressRevision.value++;
                }
              }
            : null,
        isCancelled: () => _cancelDownloadRequested,
      );
    } finally {
      await work.release();
      _cancelDownloadRequested = false;
      _isDownloadingFastDrop = false;
      _fastDropDownloadProgress = null;
      _transferStartedAt = null;
      _transferProgressRevision.value++;
      notifyListeners();
    }
  }

  bool _shouldNotifyTransferProgress({
    required int current,
    required int total,
    required bool isUpload,
  }) {
    if (total > 0 && current >= total) {
      if (isUpload) {
        _lastUploadProgressNotifyMs = 0;
      } else {
        _lastDownloadProgressNotifyMs = 0;
      }
      return true;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = isUpload
        ? _lastUploadProgressNotifyMs
        : _lastDownloadProgressNotifyMs;
    if (now - last >= 120) {
      if (isUpload) {
        _lastUploadProgressNotifyMs = now;
      } else {
        _lastDownloadProgressNotifyMs = now;
      }
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _transferProgressRevision.dispose();
    super.dispose();
  }
}
