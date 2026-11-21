import 'dart:convert';
import 'dart:typed_data';

import 'package:tool_lab/helpers/debug_log.dart';

import 'api/local_station_client.dart';
import 'api/mosmix_client.dart';
import 'api/nowcast_client.dart';
import 'api/observation_client.dart';
import 'api/station_catalog.dart';
import 'api/warnwetter_client.dart';
import 'api/weather_http.dart';
import 'models/area_warning.dart';
import 'models/day_astronomy.dart';
import 'models/local_station_manifest.dart';
import 'models/mosmix_forecast.dart';
import 'models/station_overview.dart';
import 'models/weather_history_entry.dart';
import 'models/weather_location.dart';
import 'models/weather_observation.dart';
import 'models/weather_snapshot.dart';
import 'models/weather_warning.dart';
import 'weather_db_helper.dart';

/// Loads a [WeatherSnapshot] with a raw-payload cache in the tool database.
/// Has no provider dependency so the background task can use it as well.
class WeatherRepository {
  WeatherRepository({
    WeatherDbHelper? db,
    Future<Uint8List> Function(Uri uri, {Map<String, String> headers})? fetch,
    DateTime Function()? clock,
  }) : _db = db ?? WeatherDbHelper.instance,
       _fetch = fetch ?? WeatherHttp.getBytes,
       _clock = clock ?? DateTime.now;

  static const Duration forecastMaxAge = Duration(minutes: 60);
  static const Duration observationMaxAge = Duration(minutes: 10);
  static const Duration overviewMaxAge = Duration(minutes: 15);
  static const Duration nowcastMaxAge = Duration(minutes: 5);
  static const Duration manifestMaxAge = Duration(hours: 1);
  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
  };
  static const int _candidates = 3;
  static const int _overviewFallbacks = 6;

  final WeatherDbHelper _db;
  final Future<Uint8List> Function(Uri uri, {Map<String, String> headers})
  _fetch;
  final DateTime Function() _clock;

  /// [cacheOnly] answers from the tool database alone, whatever its age, so
  /// the screen can show the last known weather while the network loads.
  Future<WeatherSnapshot> load(
    WeatherLocation location,
    StationCatalog catalog, {
    bool force = false,
    bool cacheOnly = false,
  }) async {
    final mode = cacheOnly
        ? _Mode.cacheOnly
        : (force ? _Mode.force : _Mode.normal);
    final manifest = location.stationUrl == null
        ? null
        : await _loadManifest(location.stationUrl!, mode);
    final local = manifest?.value;
    final results = await Future.wait([
      _forecastFor(location, catalog, local, mode),
      _observationsFor(location, catalog, local, mode),
      _loadNowcast(location, mode),
    ]);
    final forecast = results[0] as _Loaded<MosmixForecast>?;
    final observations = results[1] as _Loaded<ObservationSeries>?;
    final nowcast = results[2] as List<WeatherWarning>;
    final overview = await _overviewFor(
      location,
      catalog,
      local,
      forecast?.station,
      mode,
    );

    final errors = [
      manifest?.error,
      forecast?.error,
      observations?.error,
      overview?.error,
    ].nonNulls;
    final snapshot = WeatherSnapshot(
      location: location,
      fetchedAt: cacheOnly ? (forecast?.time ?? _clock()) : _clock(),
      forecastStation: forecast?.station,
      observationStation: observations?.station,
      forecast: forecast?.value,
      observations: observations?.value,
      overview: overview?.value,
      nowcastWarnings: nowcast,
      isStale: [
        manifest,
        forecast,
        observations,
        overview,
      ].any((l) => l?.stale ?? false),
      error: forecast?.value == null
          ? (forecast?.error ?? WeatherError.notFound)
          : errors.firstOrNull,
    );
    if (!cacheOnly && location.id != null) {
      await _recordHistory(location.id!, snapshot);
    }
    return snapshot;
  }

  /// Every network load extends the place's history; a failure only costs
  /// those hours.
  Future<void> _recordHistory(int locationId, WeatherSnapshot snapshot) async {
    try {
      await _db.recordHistory(
        WeatherHistoryEntry.fromSnapshot(locationId, snapshot, _clock()),
      );
    } catch (e) {
      errorLog('[WeatherRepository] history for $locationId failed: $e');
    }
  }

  /// Reads a local station's manifest for the add dialog and caches it, so
  /// the first load of the new place needs no second request.
  Future<LocalStationManifest> inspectLocalStation(Uri url) async {
    final bytes = await _fetch(url, headers: _jsonHeaders);
    final manifest = LocalStationClient.parseManifest(bytes, url);
    await _db.putCache(_manifestKey(url.toString()), bytes, _clock());
    return manifest;
  }

  static String _manifestKey(String url) => 'local:manifest:$url';

  /// A failed station counts as offline: the place shows DWD data instead.
  Future<_Loaded<LocalStationManifest>> _loadManifest(
    String url,
    _Mode mode,
  ) async {
    final uri = Uri.parse(url);
    final loaded = await _cached(
      _manifestKey(url),
      uri,
      manifestMaxAge,
      mode,
      (bytes) => LocalStationClient.parseManifest(bytes, uri),
      headers: _jsonHeaders,
    );
    return _Loaded(
      null,
      loaded.value,
      loaded.stale || (loaded.error != null && mode != _Mode.cacheOnly),
      loaded.error,
    );
  }

  Future<_CacheResult<T>> _localSection<T>(
    LocalStationEndpoint endpoint,
    _Mode mode,
    T? Function(Uint8List bytes) parse,
  ) => _cached(
    'local:${endpoint.url}',
    endpoint.url,
    endpoint.maxAge,
    mode,
    parse,
    headers: _jsonHeaders,
  );

  Future<_Loaded<MosmixForecast>?> _forecastFor(
    WeatherLocation location,
    StationCatalog catalog,
    LocalStationManifest? manifest,
    _Mode mode,
  ) async {
    final endpoint = manifest?[LocalStationSection.forecast];
    if (endpoint == null) return _loadForecast(location, catalog, mode);
    final local = await _localSection(
      endpoint,
      mode,
      (bytes) => LocalStationClient.parseForecast(
        bytes,
        manifest!.id,
        endpoint.fields,
      ),
    );
    if (local.value != null) {
      return _Loaded(
        StationMatch(manifest!.station, 0),
        local.value,
        local.stale,
        local.error,
        local.time,
      );
    }
    return _fallback(local, await _loadForecast(location, catalog, mode), mode);
  }

  Future<_Loaded<ObservationSeries>?> _observationsFor(
    WeatherLocation location,
    StationCatalog catalog,
    LocalStationManifest? manifest,
    _Mode mode,
  ) async {
    final endpoint = manifest?[LocalStationSection.observations];
    if (endpoint == null) return _loadObservations(location, catalog, mode);
    final local = await _localSection(
      endpoint,
      mode,
      (bytes) => LocalStationClient.parseObservations(
        bytes,
        manifest!.id,
        endpoint.fields,
      ),
    );
    if (local.value != null) {
      return _Loaded(
        StationMatch(manifest!.station, 0),
        local.value,
        local.stale,
        local.error,
      );
    }
    return _fallback(
      local,
      await _loadObservations(location, catalog, mode),
      mode,
    );
  }

  /// DWD data standing in for a local section that delivered nothing keeps
  /// the station's error and shows the place as offline.
  _Loaded<T>? _fallback<T>(_CacheResult<T> local, _Loaded<T>? dwd, _Mode mode) {
    final failed = local.error != null && mode != _Mode.cacheOnly;
    if (dwd == null) {
      return failed ? _Loaded(null, null, true, local.error) : null;
    }
    return _Loaded(
      dwd.station,
      dwd.value,
      dwd.stale || failed,
      local.error ?? dwd.error,
      dwd.time,
    );
  }

  /// Local warnings and days replace the DWD ones section by section.
  Future<_Loaded<StationOverview>?> _overviewFor(
    WeatherLocation location,
    StationCatalog catalog,
    LocalStationManifest? manifest,
    StationMatch? forecastStation,
    _Mode mode,
  ) async {
    final warningsAt = manifest?[LocalStationSection.warnings];
    final daysAt = manifest?[LocalStationSection.days];
    final String? dwdStation;
    if (forecastStation != null && !forecastStation.station.isLocal) {
      dwdStation = forecastStation.station.id;
    } else if (manifest != null) {
      dwdStation = catalog
          .nearest(location.latitude, location.longitude, limit: 1)
          .firstOrNull
          ?.station
          .id;
    } else {
      dwdStation = null;
    }
    final loaded = await Future.wait([
      warningsAt == null
          ? Future.value(null)
          : _localSection(warningsAt, mode, LocalStationClient.parseWarnings),
      daysAt == null
          ? Future.value(null)
          : _localSection(
              daysAt,
              mode,
              (bytes) => LocalStationClient.parseDays(bytes, daysAt.fields),
            ),
      (warningsAt != null && daysAt != null) || dwdStation == null
          ? Future.value(null)
          : _loadOverview(location, dwdStation, catalog, mode),
    ]);
    final warnings = loaded[0] as _CacheResult<List<WeatherWarning>>?;
    final days = loaded[1] as _CacheResult<List<DayAstronomy>>?;
    final dwd = loaded[2] as _Loaded<StationOverview>?;
    if (warnings == null && days == null) return dwd;
    final localError = warnings?.error ?? days?.error;
    return _Loaded(
      null,
      StationOverview(
        days: days?.value ?? dwd?.value?.days ?? const [],
        warnings: warnings?.value ?? dwd?.value?.warnings ?? const [],
      ),
      (warnings?.stale ?? false) ||
          (days?.stale ?? false) ||
          (dwd?.stale ?? false) ||
          (localError != null && mode != _Mode.cacheOnly),
      localError ?? dwd?.error,
    );
  }

  List<StationMatch> _stations(
    WeatherLocation location,
    StationCatalog catalog, {
    required String? pinned,
    required bool observations,
  }) {
    final pinnedStation = pinned == null ? null : catalog.byId(pinned);
    if (pinnedStation != null) {
      return [
        StationMatch(
          pinnedStation,
          pinnedStation.distanceKm(location.latitude, location.longitude),
        ),
      ];
    }
    return catalog.nearest(
      location.latitude,
      location.longitude,
      elevation: location.elevation,
      observationsOnly: observations,
      limit: _candidates,
      maxDistanceKm: observations ? 60 : 100,
    );
  }

  Future<_Loaded<MosmixForecast>?> _loadForecast(
    WeatherLocation location,
    StationCatalog catalog,
    _Mode mode,
  ) async {
    WeatherError? lastError;
    for (final match in _stations(
      location,
      catalog,
      pinned: location.forecastStationId,
      observations: false,
    )) {
      final id = match.station.id;
      final loaded = await _cached(
        'mosmix:$id',
        MosmixClient.url(id),
        forecastMaxAge,
        mode,
        (bytes) => MosmixClient.parseKmz(bytes, id),
      );
      if (loaded.value != null) {
        return _Loaded(
          match,
          loaded.value,
          loaded.stale,
          loaded.error,
          loaded.time,
        );
      }
      lastError = loaded.error;
    }
    return lastError == null ? null : _Loaded(null, null, false, lastError);
  }

  Future<_Loaded<ObservationSeries>?> _loadObservations(
    WeatherLocation location,
    StationCatalog catalog,
    _Mode mode,
  ) async {
    for (final match in _stations(
      location,
      catalog,
      pinned: location.observationStationId,
      observations: true,
    )) {
      final id = match.station.id;
      final loaded = await _cached(
        'obs:$id',
        ObservationClient.url(id),
        observationMaxAge,
        mode,
        (bytes) => ObservationClient.parseCsv(
          utf8.decode(bytes, allowMalformed: true),
          id,
        ),
      );
      final latest = loaded.value?.latest;
      final isCurrent =
          latest != null &&
          _clock().difference(latest.time) <= WeatherSnapshot.observationMaxAge;
      if (isCurrent || location.observationStationId != null) {
        return _Loaded(match, loaded.value, loaded.stale, loaded.error);
      }
    }
    return null;
  }

  /// One file covers all of Germany; a place gets the areas it lies in.
  /// A failure only costs the short-term warnings, never the snapshot.
  Future<List<WeatherWarning>> _loadNowcast(
    WeatherLocation location,
    _Mode mode,
  ) async {
    final loaded = await _cached<List<AreaWarning>>(
      'nowcast',
      NowcastClient.url(),
      nowcastMaxAge,
      mode,
      NowcastClient.parse,
    );
    return [
      for (final a in loaded.value ?? const <AreaWarning>[])
        if (a.contains(location.latitude, location.longitude)) a.warning,
    ];
  }

  /// The WarnWetter backend knows only part of the MOSMIX stations, so the
  /// nearest others are asked along in the same request as fallbacks.
  Future<_Loaded<StationOverview>> _loadOverview(
    WeatherLocation location,
    String stationId,
    StationCatalog catalog,
    _Mode mode,
  ) async {
    final ids = <String>{
      stationId,
      for (final m in catalog.nearest(
        location.latitude,
        location.longitude,
        limit: _overviewFallbacks,
        maxDistanceKm: 60,
      ))
        m.station.id,
    }.toList();
    final loaded = await _cached(
      'overview:${ids.join(',')}',
      WarnwetterClient.url(ids),
      overviewMaxAge,
      mode,
      (bytes) {
        final stations = WarnwetterClient.parse(utf8.decode(bytes));
        for (final id in ids) {
          final hit = stations[id];
          if (hit != null) return hit;
        }
        return null;
      },
      headers: const {'Accept': 'application/json'},
    );
    return _Loaded(null, loaded.value, loaded.stale, loaded.error);
  }

  Future<_CacheResult<T>> _cached<T>(
    String key,
    Uri uri,
    Duration maxAge,
    _Mode mode,
    T? Function(Uint8List bytes) parse, {
    Map<String, String> headers = const {},
  }) async {
    final now = _clock();
    final cached = await _db.getCache(key);
    T? fromCache() {
      if (cached == null) return null;
      try {
        return parse(cached.body);
      } catch (e) {
        debugLog('[WeatherRepository] cache $key unreadable: $e');
        return null;
      }
    }

    if (mode == _Mode.cacheOnly) {
      final value = fromCache();
      return _CacheResult(
        value,
        false,
        value == null ? WeatherError.notFound : null,
        cached?.fetchedAt,
      );
    }
    if (mode == _Mode.normal && cached != null && cached.isFresh(maxAge, now)) {
      final value = fromCache();
      if (value != null) {
        return _CacheResult(value, false, null, cached.fetchedAt);
      }
    }
    try {
      final bytes = await _fetch(uri, headers: headers);
      final value = parse(bytes);
      if (value == null) throw const WeatherException(WeatherError.invalidData);
      await _db.putCache(key, bytes, now);
      return _CacheResult(value, false, null, now);
    } on WeatherException catch (e) {
      debugLog('[WeatherRepository] $key failed: $e');
      // A station that is gone should hand over to the next one, not live on
      // from the cache.
      if (e.error == WeatherError.notFound) {
        return _CacheResult(null, false, e.error, null);
      }
      final value = fromCache();
      return _CacheResult(value, value != null, e.error, cached?.fetchedAt);
    }
  }
}

enum _Mode { normal, force, cacheOnly }

class _CacheResult<T> {
  const _CacheResult(this.value, this.stale, this.error, this.time);

  final T? value;
  final bool stale;
  final WeatherError? error;
  final DateTime? time;
}

class _Loaded<T> {
  const _Loaded(this.station, this.value, this.stale, this.error, [this.time]);

  final StationMatch? station;
  final T? value;
  final bool stale;
  final WeatherError? error;
  final DateTime? time;
}
