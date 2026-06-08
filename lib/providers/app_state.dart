import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/shortcut_service.dart';
import 'package:tool_lab/services/sync_service.dart';
import 'package:tool_lab/tools/notes/notes_db_helper.dart';
import 'package:tool_lab/tools/notes/notes_sync_delegate.dart';
import 'package:tool_lab/tools/fast_drop/fast_drop_model.dart';
import 'package:tool_lab/tools/fast_drop/fast_drop_service.dart';

class AppState extends ChangeNotifier {
  final SettingsService _settingsService;

  AppState(this._settingsService) {
    _themeMode = _settingsService.getThemeMode();
    _compactMode = _settingsService.getCompactMode();
    _sortBy = _settingsService.getSortBy();
    _syncEnabled = _settingsService.getSyncEnabled();
    _systemNotificationsEnabled = _settingsService
        .getSystemNotificationsEnabled();
    _syncServerUrl = _settingsService.getSyncServerUrl();
    _syncUserId = _settingsService.getSyncUserId();
    _syncLastSynced = _settingsService.getSyncLastSynced();
    _loadFavorites();
    _loadRecentTimestamps();
    _loadPinnedShortcuts();
    _loadDrawerIcons();
    registerSyncDelegate(NotesSyncDelegate());
  }

  ThemeMode _themeMode = ThemeMode.system;
  bool _compactMode = true;
  String _sortBy = 'recent';
  String _searchQuery = '';
  Set<String> _favorites = {};
  Map<String, int> _recentTimestamps = {};
  Map<String, bool> _pinnedShortcuts = {};
  Map<String, bool> _drawerIcons = {};

  Map<String, bool> get pinnedShortcuts => _pinnedShortcuts;
  Map<String, bool> get drawerIcons => _drawerIcons;

  bool _syncEnabled = false;
  bool _systemNotificationsEnabled = true;
  String _syncServerUrl = '';
  String _syncUserId = '';
  int _syncLastSynced = 0;
  bool _isSyncing = false;
  final List<SyncDelegate> _syncDelegates = [];

  ThemeMode get themeMode => _themeMode;
  bool get compactMode => _compactMode;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;
  Set<String> get favorites => _favorites;
  Map<String, int> get recentTimestamps => _recentTimestamps;

  bool get syncEnabled => _syncEnabled;
  bool get systemNotificationsEnabled => _systemNotificationsEnabled;
  String get syncServerUrl => _syncServerUrl;
  String get syncUserId => _syncUserId;
  int get syncLastSynced => _syncLastSynced;
  bool get isSyncing => _isSyncing;
  List<SyncDelegate> get syncDelegates => List.unmodifiable(_syncDelegates);

  void registerSyncDelegate(SyncDelegate delegate) {
    if (!_syncDelegates.any((d) => d.toolId == delegate.toolId)) {
      _syncDelegates.add(delegate);
    }
  }

  bool isFavorite(String toolId) => _favorites.contains(toolId);

  int getLastUsed(String toolId) => _recentTimestamps[toolId] ?? 0;

  Future<void> _loadFavorites() async {
    _favorites = await DatabaseService.instance.getFavoriteIds();
    notifyListeners();
  }

  Future<void> _loadRecentTimestamps() async {
    _recentTimestamps = await DatabaseService.instance.getRecentTimestamps();
    notifyListeners();
  }

  Future<void> _loadPinnedShortcuts() async {
    final Map<String, bool> result = {};
    for (final tool in ToolRegistry.all) {
      final value = await DatabaseService.instance.getSetting(
        tool.id,
        'pinned_shortcut',
      );
      result[tool.id] = value == 'true';
    }
    _pinnedShortcuts = result;
    notifyListeners();
  }

  Future<void> pinShortcut(String toolId, String toolName) async {
    final success = await ShortcutService.instance.pinShortcut(
      toolId,
      toolName,
    );
    if (success) {
      await DatabaseService.instance.setSetting(
        toolId,
        'pinned_shortcut',
        'true',
      );
      _pinnedShortcuts[toolId] = true;
      notifyListeners();
    }
  }

  Future<void> _loadDrawerIcons() async {
    final Map<String, bool> result = {};
    for (final tool in ToolRegistry.all) {
      final value = await DatabaseService.instance.getSetting(
        tool.id,
        'drawer_icon',
      );
      result[tool.id] = value == 'true';
    }
    _drawerIcons = result;
    notifyListeners();
  }

  Future<void> toggleDrawerIcon(String toolId) async {
    final currentVal = _drawerIcons[toolId] ?? false;
    final newVal = !currentVal;
    await ShortcutService.instance.setDrawerIconEnabled(toolId, newVal);
    await DatabaseService.instance.setSetting(
      toolId,
      'drawer_icon',
      newVal ? 'true' : 'false',
    );
    _drawerIcons[toolId] = newVal;
    notifyListeners();
  }

  Future<void> toggleFavorite(String toolId) async {
    final newState = !_favorites.contains(toolId);
    await DatabaseService.instance.setFavorite(toolId, newState);
    if (newState) {
      _favorites.add(toolId);
    } else {
      _favorites.remove(toolId);
    }
    notifyListeners();
  }

  Future<void> recordToolUsage(String toolId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await DatabaseService.instance.touchToolUsage(toolId);
    _recentTimestamps[toolId] = now;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settingsService.setThemeMode(mode);
    notifyListeners();
  }

  void toggleCompactMode() {
    _compactMode = !_compactMode;
    _settingsService.setCompactMode(_compactMode);
    notifyListeners();
  }

  Future<void> setSystemNotificationsEnabled(bool value) async {
    _systemNotificationsEnabled = value;
    await _settingsService.setSystemNotificationsEnabled(value);
    notifyListeners();
  }

  Future<void> setSortBy(String value) async {
    _sortBy = value;
    await _settingsService.setSortBy(value);
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> setSyncEnabled(bool value) async {
    _syncEnabled = value;
    await _settingsService.setSyncEnabled(value);
    notifyListeners();
  }

  Future<void> saveSyncSettings({
    required bool enabled,
    required String url,
    required String userId,
  }) async {
    _syncEnabled = enabled;
    _syncServerUrl = url;
    _syncUserId = userId;
    await _settingsService.setSyncEnabled(enabled);
    await _settingsService.setSyncServerUrl(url);
    await _settingsService.setSyncUserId(userId);
    notifyListeners();
  }

  Future<Map<String, int>?> syncWithBackend(
    List<SyncDelegate> delegates,
  ) async {
    if (_isSyncing) return null;
    if (_syncServerUrl.isEmpty) return null;

    _isSyncing = true;
    notifyListeners();

    int pulledTotal = 0;
    int pushedTotal = 0;
    int deletedTotal = 0;

    try {
      final available = await SyncService.isBackendAvailable(_syncServerUrl);
      if (!available) {
        throw Exception('Backend server unreachable');
      }

      for (final delegate in delegates) {
        final results = await SyncService.sync(
          baseUrl: _syncServerUrl,
          userId: _syncUserId,
          delegate: delegate,
        );
        pulledTotal += results['pulled'] ?? 0;
        pushedTotal += results['pushed'] ?? 0;
        deletedTotal += results['deleted'] ?? 0;
      }

      _syncLastSynced = DateTime.now().millisecondsSinceEpoch;
      await _settingsService.setSyncLastSynced(_syncLastSynced);
      return {
        'pulled': pulledTotal,
        'pushed': pushedTotal,
        'deleted': deletedTotal,
      };
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Exports the SQLite database file as raw bytes.
  Future<Uint8List> getDatabaseBytes() async {
    return await DatabaseService.instance.getDatabaseBytes();
  }

  /// Exports global settings as a JSON string.
  String exportSettingsToJson() {
    return _settingsService.exportSettingsToJson();
  }

  List<Map<String, dynamic>> _notes = [];
  bool _isLoadingNotes = false;

  List<Map<String, dynamic>> get notes => _notes;
  bool get isLoadingNotes => _isLoadingNotes;

  Future<void> loadNotes({String query = ''}) async {
    _isLoadingNotes = true;
    notifyListeners();
    try {
      _notes = await NotesDbHelper.instance.getActiveNotes(query: query);
    } catch (e) {
      debugPrint('[AppState] Failed to load notes: $e');
    } finally {
      _isLoadingNotes = false;
      notifyListeners();
    }
  }

  Future<void> saveNote(String content, {int? id, String? shortId}) async {
    await NotesDbHelper.instance.saveNote(content, id: id, shortId: shortId);
    await loadNotes();
    if (_syncEnabled && _syncServerUrl.isNotEmpty) {
      // Sync in background
      syncWithBackend([NotesSyncDelegate()]).catchError((e) {
        debugPrint('[AppState] Background sync failed: $e');
        return null;
      });
    }
  }

  Future<void> deleteNote(int id) async {
    await NotesDbHelper.instance.softDeleteNote(id);
    await loadNotes();
    if (_syncEnabled && _syncServerUrl.isNotEmpty) {
      // Sync in background
      syncWithBackend([NotesSyncDelegate()]).catchError((e) {
        debugPrint('[AppState] Background sync failed: $e');
        return null;
      });
    }
  }

  Future<void> importNotesFromJson(List<Map<String, dynamic>> notesList) async {
    for (final note in notesList) {
      final content = note['content'] as String? ?? '';
      if (content.trim().isEmpty) continue;
      final shortId = note['shortId'] as String?;
      final createdAt = note['createdAt'] as int?;
      final updatedAt = note['updatedAt'] as int?;

      final existing = shortId != null
          ? await NotesDbHelper.instance.getNoteByShortId(shortId)
          : null;
      if (existing == null) {
        await NotesDbHelper.instance.savePulledNote(
          shortId: shortId ?? NotesDbHelper.instance.generateShortId(),
          content: content,
          createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        );
      }
    }
    await loadNotes();
    if (_syncEnabled && _syncServerUrl.isNotEmpty) {
      syncWithBackend([NotesSyncDelegate()]).catchError((e) => null);
    }
  }

  List<FastDropItem> _fastDrops = [];
  bool _isLoadingFastDrops = false;
  bool _isUploadingFastDrop = false;
  String? _fastDropError;
  bool _isServerAvailable = true;

  List<FastDropItem> get fastDrops => _fastDrops;
  bool get isLoadingFastDrops => _isLoadingFastDrops;
  bool get isUploadingFastDrop => _isUploadingFastDrop;
  String? get fastDropError => _fastDropError;
  bool get isServerAvailable => _isServerAvailable;

  Future<void> loadFastDrops() async {
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
      debugPrint('[AppState] Failed to load Fast Drops: $e');
    } finally {
      _isLoadingFastDrops = false;
      notifyListeners();
    }
  }

  Future<void> uploadFastDrop({
    required String filename,
    required Uint8List bytes,
    required String retention,
    required String source,
    required String mimeType,
  }) async {
    if (_syncServerUrl.isEmpty) {
      throw Exception('Sync Server URL is not configured');
    }

    _isUploadingFastDrop = true;
    notifyListeners();

    try {
      await FastDropService.uploadDrop(
        baseUrl: _syncServerUrl,
        filename: filename,
        bytes: bytes,
        retention: retention,
        source: source,
        mimeType: mimeType,
      );
      await loadFastDrops();
    } finally {
      _isUploadingFastDrop = false;
      notifyListeners();
    }
  }

  Future<void> deleteFastDrop(String id) async {
    if (_syncServerUrl.isEmpty) return;
    try {
      await FastDropService.deleteDrop(_syncServerUrl, id);
      await loadFastDrops();
    } catch (e) {
      debugPrint('[AppState] Failed to delete Fast Drop: $e');
      rethrow;
    }
  }

  Future<void> keepFastDrop(String id) async {
    if (_syncServerUrl.isEmpty) return;
    try {
      await FastDropService.keepDrop(_syncServerUrl, id);
      await loadFastDrops();
    } catch (e) {
      debugPrint('[AppState] Failed to update Fast Drop retention: $e');
      rethrow;
    }
  }

  Future<Uint8List> downloadFastDrop(String id) async {
    if (_syncServerUrl.isEmpty) {
      throw Exception('Sync Server URL is not configured');
    }
    return await FastDropService.downloadDrop(_syncServerUrl, id);
  }
}
