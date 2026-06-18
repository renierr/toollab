import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/shortcut_service.dart';
import 'package:tool_lab/services/sync_service.dart';

class AppState extends ChangeNotifier {
  final SettingsService _settingsService;

  AppState(this._settingsService) {
    _themeMode = _settingsService.getThemeMode();
    _locale = _settingsService.getLocale();
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
    for (final tool in ToolRegistry.all) {
      final factory = tool.syncDelegateFactory;
      if (factory != null) registerSyncDelegate(factory());
    }
  }

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
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

  /// The selected UI locale, or null to follow the system language.
  Locale? get locale => _locale;

  /// Locales the app ships translations for.
  List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

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

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    await _settingsService.setLocale(locale);
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

  /// Reloads all in-memory state from the database after an import, so the UI
  /// reflects the restored data and settings without an app restart.
  Future<void> reloadFromDatabase() async {
    await _settingsService.reload();
    _themeMode = _settingsService.getThemeMode();
    _locale = _settingsService.getLocale();
    _compactMode = _settingsService.getCompactMode();
    _sortBy = _settingsService.getSortBy();
    _syncEnabled = _settingsService.getSyncEnabled();
    _systemNotificationsEnabled = _settingsService
        .getSystemNotificationsEnabled();
    _syncServerUrl = _settingsService.getSyncServerUrl();
    _syncUserId = _settingsService.getSyncUserId();
    _syncLastSynced = _settingsService.getSyncLastSynced();
    await _loadFavorites();
    await _loadRecentTimestamps();
    await _loadPinnedShortcuts();
    await _loadDrawerIcons();
    notifyListeners();
  }
}
