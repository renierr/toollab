import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'fast_drop_model.dart';
import 'fast_drop_service.dart';

class FastDropState extends ChangeNotifier {
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
  String _syncServerUrl = '';

  List<FastDropItem> get fastDrops => _fastDrops;
  bool get isLoadingFastDrops => _isLoadingFastDrops;
  bool get isUploadingFastDrop => _isUploadingFastDrop;
  bool get isDownloadingFastDrop => _isDownloadingFastDrop;
  (int sent, int total)? get fastDropUploadProgress => _fastDropUploadProgress;
  (int received, int total)? get fastDropDownloadProgress =>
      _fastDropDownloadProgress;
  String? get fastDropError => _fastDropError;
  bool get isServerAvailable => _isServerAvailable;

  Future<String> _loadServerUrl() async {
    _syncServerUrl =
        (await DatabaseService.instance.getSetting(
          '_app',
          'sync_server_url',
        )) ??
        '';
    return _syncServerUrl;
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
      debugPrint('[FastDropState] Failed to load Fast Drops: $e');
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
    notifyListeners();

    try {
      await FastDropService.uploadDrop(
        baseUrl: _syncServerUrl,
        filename: filename,
        filePath: filePath,
        retention: retention,
        source: source,
        mimeType: mimeType,
        onProgress: (sent, total) {
          _fastDropUploadProgress = (sent, total);
          if (_shouldNotifyTransferProgress(
            current: sent,
            total: total,
            isUpload: true,
          )) {
            notifyListeners();
          }
        },
        isCancelled: () => _cancelUploadRequested,
      );
      await loadFastDrops();
    } finally {
      _cancelUploadRequested = false;
      _isUploadingFastDrop = false;
      _fastDropUploadProgress = null;
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
      debugPrint('[FastDropState] Failed to delete Fast Drop: $e');
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
      debugPrint('[FastDropState] Failed to update Fast Drop retention: $e');
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
      debugPrint('[FastDropState] Failed to update Fast Drop description: $e');
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
      debugPrint('[FastDropState] Failed to update Fast Drop retention: $e');
      rethrow;
    }
  }

  Future<Uint8List> downloadFastDrop(String id, {int? knownSize}) async {
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
    if (size == null) {
      for (final item in _fastDrops) {
        if (item.id == id) {
          size = item.size;
          break;
        }
      }
    }

    _cancelDownloadRequested = false;
    _isDownloadingFastDrop = true;
    _fastDropDownloadProgress = null;
    _lastDownloadProgressNotifyMs = 0;
    notifyListeners();

    try {
      return await FastDropService.downloadDrop(
        baseUrl: _syncServerUrl,
        id: id,
        onProgress: (received, total) {
          final effectiveTotal = total > 0 ? total : (size ?? -1);
          _fastDropDownloadProgress = (received, effectiveTotal);
          if (_shouldNotifyTransferProgress(
            current: received,
            total: effectiveTotal,
            isUpload: false,
          )) {
            notifyListeners();
          }
        },
        isCancelled: () => _cancelDownloadRequested,
      );
    } finally {
      _cancelDownloadRequested = false;
      _isDownloadingFastDrop = false;
      _fastDropDownloadProgress = null;
      notifyListeners();
    }
  }

  Future<String> downloadFastDropToFile({
    required String id,
    required String outputPath,
    int? knownSize,
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
    if (size == null) {
      for (final item in _fastDrops) {
        if (item.id == id) {
          size = item.size;
          break;
        }
      }
    }

    _cancelDownloadRequested = false;
    _isDownloadingFastDrop = true;
    _fastDropDownloadProgress = null;
    _lastDownloadProgressNotifyMs = 0;
    notifyListeners();

    try {
      return await FastDropService.downloadDropToFile(
        baseUrl: _syncServerUrl,
        id: id,
        outputPath: outputPath,
        onProgress: (received, total) {
          final effectiveTotal = total > 0 ? total : (size ?? -1);
          _fastDropDownloadProgress = (received, effectiveTotal);
          if (_shouldNotifyTransferProgress(
            current: received,
            total: effectiveTotal,
            isUpload: false,
          )) {
            notifyListeners();
          }
        },
        isCancelled: () => _cancelDownloadRequested,
      );
    } finally {
      _cancelDownloadRequested = false;
      _isDownloadingFastDrop = false;
      _fastDropDownloadProgress = null;
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
}
