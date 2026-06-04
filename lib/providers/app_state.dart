import 'package:flutter/material.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/settings_service.dart';

class AppState extends ChangeNotifier {
  final SettingsService _settingsService;

  AppState(this._settingsService) {
    _themeMode = _settingsService.getThemeMode();
    _compactMode = _settingsService.getCompactMode();
    _sortBy = _settingsService.getSortBy();
    _loadFavorites();
    _loadRecentTimestamps();
  }

  ThemeMode _themeMode = ThemeMode.system;
  bool _compactMode = true;
  String _sortBy = 'recent';
  String _searchQuery = '';
  Set<String> _favorites = {};
  Map<String, int> _recentTimestamps = {};

  ThemeMode get themeMode => _themeMode;
  bool get compactMode => _compactMode;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;
  Set<String> get favorites => _favorites;
  Map<String, int> get recentTimestamps => _recentTimestamps;

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

  Future<void> setSortBy(String value) async {
    _sortBy = value;
    await _settingsService.setSortBy(value);
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }
}
