import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/services/background_task_service.dart';

import 'api/geocoding_client.dart';
import 'api/station_catalog.dart';
import 'models/geo_place.dart';
import 'models/weather_location.dart';
import 'models/weather_snapshot.dart';
import 'weather_background.dart';
import 'weather_db_helper.dart';
import 'weather_device_location.dart';
import 'weather_publisher.dart';
import 'weather_repository.dart';
import 'weather_settings.dart';

class WeatherState extends ChangeNotifier {
  WeatherState({
    WeatherRepository? repository,
    WeatherDbHelper? db,
    Future<StationCatalog> Function()? catalogLoader,
    this._geocoding = const GeocodingClient(),
    Future<WeatherSettings> Function()? settingsLoader,
    Future<DeviceFix> Function({required bool mayPrompt})? deviceLocation,
    Future<void> Function()? publish,
  }) : _publish = publish ?? WeatherPublisher.publish,
       _db = db ?? WeatherDbHelper.instance,
       _repository = repository ?? WeatherRepository(db: db),
       _catalogLoader = catalogLoader ?? StationCatalog.load,
       _settingsLoader = settingsLoader ?? WeatherSettings.load,
       _deviceLocation = deviceLocation ?? WeatherDeviceLocation.current;

  /// Nominatim allows one request per second.
  static const Duration _searchSpacing = Duration(seconds: 1);

  /// Collects a burst of refreshes or edits into one widget publish.
  static const Duration _publishDelay = Duration(seconds: 3);

  final WeatherDbHelper _db;
  final WeatherRepository _repository;
  final Future<StationCatalog> Function() _catalogLoader;
  final GeocodingClient _geocoding;
  final Future<WeatherSettings> Function() _settingsLoader;
  final Future<DeviceFix> Function({required bool mayPrompt}) _deviceLocation;
  final Future<void> Function() _publish;
  Timer? _publishTimer;

  Future<void>? _loading;
  StationCatalog? _catalog;
  WeatherSettings _settings = const WeatherSettings();
  List<WeatherLocation> _locations = const [];
  final Map<int, WeatherSnapshot> _snapshots = {};
  final Map<int, Future<void>> _refreshing = {};
  int? _selectedId;
  DateTime? _lastSearch;
  DeviceLocationError? _deviceError;
  bool _disposed = false;

  bool get isLoaded => _catalog != null;
  WeatherSettings get settings => _settings;
  List<WeatherLocation> get locations => _locations;
  StationCatalog? get catalog => _catalog;
  DeviceLocationError? get deviceError => _deviceError;

  WeatherLocation? get selected => locationById(_selectedId) ?? defaultLocation;

  WeatherLocation? get defaultLocation =>
      locationById(_settings.defaultLocationId) ?? _locations.firstOrNull;

  WeatherLocation? locationById(int? id) {
    if (id == null) return null;
    for (final l in _locations) {
      if (l.id == id) return l;
    }
    return null;
  }

  WeatherSnapshot? snapshotFor(int? id) => id == null ? null : _snapshots[id];

  bool isRefreshing(int? id) => id != null && _refreshing.containsKey(id);

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _catalogLoader(),
        _settingsLoader(),
        _db.getLocations(),
      ]);
      _catalog = results[0] as StationCatalog;
      _settings = results[1] as WeatherSettings;
      _locations = results[2] as List<WeatherLocation>;
      _notify();
      final initial = selected;
      if (initial != null) unawaited(_refreshInOrder(initial.id!));
    } catch (e) {
      errorLog('[WeatherState] load failed: $e');
      _loading = null;
      rethrow;
    }
  }

  void select(int id) {
    if (_selectedId == id) return;
    _selectedId = id;
    _notify();
    final snapshot = _snapshots[id];
    if (snapshot == null || _isOutdated(snapshot)) unawaited(refresh(id));
  }

  bool _isOutdated(WeatherSnapshot snapshot) =>
      DateTime.now().difference(snapshot.fetchedAt) >
      WeatherRepository.observationMaxAge;

  /// Joins a refresh already running for [id].
  Future<void> refresh(int id, {bool force = false}) {
    final running = _refreshing[id];
    if (running != null) return running;
    final catalog = _catalog;
    final location = locationById(id);
    if (catalog == null || location == null) return Future.value();
    final future = _refresh(id, location, catalog, force);
    _refreshing[id] = future;
    _notify();
    return future;
  }

  Future<void> _refresh(
    int id,
    WeatherLocation location,
    StationCatalog catalog,
    bool force,
  ) async {
    try {
      // Last known weather first, so the screen never waits on the network.
      if (!_snapshots.containsKey(id)) {
        final cached = await _repository.load(
          location,
          catalog,
          cacheOnly: true,
        );
        if (cached.hasData && !_snapshots.containsKey(id)) {
          _snapshots[id] = cached;
          _notify();
        }
      }
      final target = location.isDeviceLocation
          ? await _updateDevicePosition(location)
          : location;
      _snapshots[id] = await _repository.load(target, catalog, force: force);
      _schedulePublish();
    } catch (e) {
      errorLog('[WeatherState] refresh $id failed: $e');
    } finally {
      _refreshing.removeWhere((key, _) => key == id);
      _notify();
    }
  }

  /// The shown place first, then the others one by one for the place list.
  Future<void> _refreshInOrder(int first) async {
    await refresh(first);
    for (final l in [..._locations]) {
      if (l.id != first && !_disposed) await refresh(l.id!);
    }
  }

  Future<void> refreshAll({bool force = false}) =>
      Future.wait([for (final l in _locations) refresh(l.id!, force: force)]);

  Future<WeatherLocation> _updateDevicePosition(
    WeatherLocation location,
  ) async {
    try {
      final fix = await _deviceLocation(mayPrompt: false);
      _deviceError = null;
      final moved = location.copyWith(
        latitude: fix.latitude,
        longitude: fix.longitude,
        elevation: fix.altitude,
      );
      await _db.saveLocation(moved);
      _replace(moved);
      return moved;
    } on DeviceLocationException catch (e) {
      _deviceError = e.error;
      return location;
    }
  }

  Future<List<GeoPlace>> searchPlaces(
    String query, {
    String language = 'de',
  }) async {
    final last = _lastSearch;
    if (last != null) {
      final wait = _searchSpacing - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastSearch = DateTime.now();
    return _geocoding.search(query, language: language);
  }

  Future<WeatherLocation> addPlace(GeoPlace place) => _add(
    WeatherLocation(
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
    ),
  );

  /// Asks for the location permission; returns null when no fix is available.
  Future<WeatherLocation?> addDeviceLocation() async {
    final existing = _locations.where((l) => l.isDeviceLocation).firstOrNull;
    try {
      final fix = await _deviceLocation(mayPrompt: true);
      _deviceError = null;
      if (existing != null) {
        select(existing.id!);
        return existing;
      }
      return await _add(
        WeatherLocation(
          name: '',
          latitude: fix.latitude,
          longitude: fix.longitude,
          elevation: fix.altitude,
          isDeviceLocation: true,
        ),
      );
    } on DeviceLocationException catch (e) {
      _deviceError = e.error;
      _notify();
      return null;
    }
  }

  Future<WeatherLocation> _add(WeatherLocation location) async {
    final saved = await _db.saveLocation(location);
    _locations = [..._locations, saved];
    _selectedId = saved.id;
    _notify();
    unawaited(refresh(saved.id!));
    return saved;
  }

  /// Returns the removed location so the caller can offer undo.
  Future<WeatherLocation?> removeLocation(int id) async {
    final removed = locationById(id);
    if (removed == null) return null;
    await _db.deleteLocation(id);
    _locations = [
      for (final l in _locations)
        if (l.id != id) l,
    ];
    _snapshots.remove(id);
    if (_selectedId == id) _selectedId = null;
    if (_settings.defaultLocationId == id) {
      await updateSettings(_settings.copyWith(defaultLocationId: () => null));
    }
    _notify();
    _schedulePublish();
    return removed;
  }

  Future<void> restoreLocation(WeatherLocation location) async {
    final saved = await _db.saveLocation(location.copyWithoutId());
    final index = location.sortOrder.clamp(0, _locations.length);
    _locations = [..._locations]..insert(index, saved);
    _locations = [
      for (var i = 0; i < _locations.length; i++)
        _locations[i].copyWith(sortOrder: i),
    ];
    await _db.reorder([for (final l in _locations) l.id!]);
    _notify();
    unawaited(refresh(saved.id!));
  }

  Future<void> rename(int id, String name) async {
    final location = locationById(id);
    final trimmed = name.trim();
    if (location == null || trimmed.isEmpty) return;
    final renamed = location.copyWith(name: trimmed);
    await _db.saveLocation(renamed);
    _replace(renamed);
    _notify();
    _schedulePublish();
  }

  /// [newIndex] is the final position, as `onReorderItem` reports it.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [..._locations];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    _locations = [
      for (var i = 0; i < list.length; i++) list[i].copyWith(sortOrder: i),
    ];
    _notify();
    await _db.reorder([for (final l in _locations) l.id!]);
  }

  /// Null station ids return to automatic selection.
  Future<void> pinStations(
    int id, {
    String? forecast,
    String? observation,
  }) async {
    final location = locationById(id);
    if (location == null) return;
    final pinned = location.withStations(
      forecast: forecast,
      observation: observation,
    );
    await _db.saveLocation(pinned);
    _replace(pinned);
    _notify();
    await refresh(id);
  }

  Future<void> setDefault(int? id) =>
      updateSettings(_settings.copyWith(defaultLocationId: () => id));

  Future<void> clearCache() async {
    await _db.clearCache();
    await refreshAll(force: true);
  }

  Future<void> updateSettings(WeatherSettings settings) async {
    final previous = _settings;
    _settings = settings;
    _notify();
    await settings.save();
    _schedulePublish();
    if (previous.wifiOnly != settings.wifiOnly ||
        previous.batteryNotLow != settings.batteryNotLow) {
      await BackgroundTaskService.reschedule(WeatherBackground.task);
    }
  }

  List<StationMatch> stationChoices(
    WeatherLocation location, {
    required bool observations,
  }) =>
      _catalog?.nearest(
        location.latitude,
        location.longitude,
        observationsOnly: observations,
        limit: 12,
        maxDistanceKm: 120,
      ) ??
      const [];

  /// Drops cached weather once the tool closes; places and settings stay.
  void release() {
    _snapshots.clear();
    _selectedId = null;
  }

  void _replace(WeatherLocation location) {
    _locations = [
      for (final l in _locations) l.id == location.id ? location : l,
    ];
  }

  /// Widget data and warning notifications follow the saved weather.
  void _schedulePublish() {
    _publishTimer?.cancel();
    _publishTimer = Timer(_publishDelay, () => unawaited(_publish()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _publishTimer?.cancel();
    super.dispose();
  }
}
