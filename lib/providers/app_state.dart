import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/core/tool_registry.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/tools/treadmill_control/treadmill_health_connect_publisher.dart';
import 'package:tool_lab/tools/treadmill_control/treadmill_sync_delegate.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/services/shortcut_service.dart';
import 'package:tool_lab/services/sync_service.dart';

class AppState extends ChangeNotifier {
  /// Per-tool setting key prefix a [SyncDelegate] stores its cursor under.
  static const String _syncCursorPrefix = 'sync_cursor_';

  final SettingsService _settingsService;

  AppState(this._settingsService) {
    _themeMode = _settingsService.getThemeMode();
    _locale = _settingsService.getLocale();
    _compactMode = _settingsService.getCompactMode();
    _sortBy = _settingsService.getSortBy();
    _syncEnabled = _settingsService.getSyncEnabled();
    _systemNotificationsEnabled = _settingsService
        .getSystemNotificationsEnabled();
    _lowLatencyAudio = _settingsService.getLowLatencyAudio();
    _syncServerUrl = _settingsService.getSyncServerUrl();
    _syncUserId = _settingsService.getSyncUserId();
    _syncLastSynced = _settingsService.getSyncLastSynced();
    _loadFavorites();
    _loadRecentTimestamps();
    _loadPinnedShortcuts();
    _loadDrawerIcons();
    _loadToolSyncEnabled();
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
  Map<String, bool> _toolSyncEnabled = {};

  Map<String, bool> get pinnedShortcuts => _pinnedShortcuts;
  Map<String, bool> get drawerIcons => _drawerIcons;

  /// Tools that ship a [SyncDelegate], in registry order.
  List<ToolModel> get syncCapableTools =>
      ToolRegistry.all.where((t) => t.syncDelegateFactory != null).toList();

  bool isToolSyncEnabled(String toolId) => _toolSyncEnabled[toolId] ?? true;

  /// Whether this tool's data actually reaches a backend right now. Asked by
  /// destructive actions that mean something different once a server holds a
  /// copy - deleting locally stops being the whole story.
  bool syncsTool(String toolId) =>
      _syncServerUrl.isNotEmpty &&
      isToolSyncEnabled(toolId) &&
      syncCapableTools.any((tool) => tool.id == toolId);

  bool _syncEnabled = false;
  bool _systemNotificationsEnabled = true;
  bool _lowLatencyAudio = true;
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
  bool get lowLatencyAudio => _lowLatencyAudio;
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

  /// A tool with no stored value counts as enabled, so tools that already synced
  /// before this switch existed keep syncing after the upgrade.
  Future<void> _loadToolSyncEnabled() async {
    final Map<String, bool> result = {};
    for (final tool in syncCapableTools) {
      final value = await DatabaseService.instance.getSetting(
        tool.id,
        'sync_enabled',
      );
      result[tool.id] = value != 'false';
    }
    _toolSyncEnabled = result;
    notifyListeners();
  }

  Future<void> setToolSyncEnabled(String toolId, bool value) async {
    await DatabaseService.instance.setSetting(
      toolId,
      'sync_enabled',
      value ? 'true' : 'false',
    );
    _toolSyncEnabled[toolId] = value;
    if (value) await _clearSyncCursors(toolId);
    notifyListeners();
  }

  /// A cursor promises everything before it was already seen. Tombstones written
  /// while a tool was switched off sit behind it, so re-enabling has to drop the
  /// cursor and let the next run re-read full metadata once.
  Future<void> _clearSyncCursors(String toolId) async {
    final settings = await DatabaseService.instance.getAllSettings(toolId);
    for (final key in settings.keys) {
      if (key.startsWith(_syncCursorPrefix)) {
        await DatabaseService.instance.deleteSetting(toolId, key);
      }
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

  Future<void> setLowLatencyAudio(bool value) async {
    _lowLatencyAudio = value;
    await _settingsService.setLowLatencyAudio(value);
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

  /// Handing finished treadmill sessions to Health Connect is device-local and
  /// has nothing to do with the backend, so it runs whether or not the treadmill
  /// tool takes part in sync, and its failure never fails the sync result. It
  /// stays ordered after the sync so sessions just pulled from the backend are
  /// published too.
  Future<void> _publishTreadmillSessions() async {
    try {
      // Manual sync: never throttled away.
      await TreadmillHealthConnectPublisher.instance.publishPendingSessions(
        force: true,
      );
    } catch (e) {
      errorLog('[AppState] Treadmill Health Connect publish failed: $e');
    }
  }

  /// Central gate for the per-tool switch: every sync path in the app funnels
  /// through here, including the tools that pass their own delegate instance,
  /// so a disabled tool can never reach the backend by any route. The treadmill
  /// Health Connect publisher is deliberately outside that gate.
  Future<Map<String, int>?> syncWithBackend(
    List<SyncDelegate> requested,
  ) async {
    if (_isSyncing) return null;

    final publishTreadmill = requested.any((d) => d is TreadmillSyncDelegate);
    final delegates = _syncServerUrl.isEmpty
        ? const <SyncDelegate>[]
        : requested.where((d) => isToolSyncEnabled(d.toolId)).toList();

    if (delegates.isEmpty) {
      if (publishTreadmill) await _publishTreadmillSessions();
      return null;
    }

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

      // One tool that cannot sync - an oversized record, a schema mismatch -
      // must not cost every other tool its run, so failures are collected and
      // reported after the rest have had their turn.
      final failures = <String>[];
      for (final delegate in delegates) {
        try {
          final results = await SyncService.sync(
            baseUrl: _syncServerUrl,
            userId: _syncUserId,
            delegate: delegate,
            backendAlreadyChecked: true,
          );
          pulledTotal += results['pulled'] ?? 0;
          pushedTotal += results['pushed'] ?? 0;
          deletedTotal += results['deleted'] ?? 0;
        } catch (e) {
          errorLog('[AppState] Sync failed for ${delegate.toolId}: $e');
          failures.add('${delegate.toolId}: $e');
        }
      }
      if (publishTreadmill) await _publishTreadmillSessions();

      if (failures.isNotEmpty) throw Exception(failures.join('; '));

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
    _lowLatencyAudio = _settingsService.getLowLatencyAudio();
    _syncServerUrl = _settingsService.getSyncServerUrl();
    _syncUserId = _settingsService.getSyncUserId();
    _syncLastSynced = _settingsService.getSyncLastSynced();
    await _loadFavorites();
    await _loadRecentTimestamps();
    await _loadPinnedShortcuts();
    await _loadDrawerIcons();
    await _loadToolSyncEnabled();
    notifyListeners();
  }
}
