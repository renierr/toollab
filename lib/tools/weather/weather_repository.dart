import 'dart:convert';
import 'dart:typed_data';

import 'package:tool_lab/helpers/debug_log.dart';

import 'api/mosmix_client.dart';
import 'api/observation_client.dart';
import 'api/station_catalog.dart';
import 'api/warnwetter_client.dart';
import 'api/weather_http.dart';
import 'models/mosmix_forecast.dart';
import 'models/station_overview.dart';
import 'models/weather_location.dart';
import 'models/weather_observation.dart';
import 'models/weather_snapshot.dart';
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
  static const int _candidates = 3;

  final WeatherDbHelper _db;
  final Future<Uint8List> Function(Uri uri, {Map<String, String> headers})
  _fetch;
  final DateTime Function() _clock;

  Future<WeatherSnapshot> load(
    WeatherLocation location,
    StationCatalog catalog, {
    bool force = false,
  }) async {
    final results = await Future.wait([
      _loadForecast(location, catalog, force),
      _loadObservations(location, catalog, force),
    ]);
    final forecast = results[0] as _Loaded<MosmixForecast>?;
    final observations = results[1] as _Loaded<ObservationSeries>?;
    final forecastStation = forecast?.station;
    final overview = forecastStation == null
        ? null
        : await _loadOverview(forecastStation.station.id, force);

    final errors = [
      forecast?.error,
      observations?.error,
      overview?.error,
    ].nonNulls;
    return WeatherSnapshot(
      location: location,
      fetchedAt: _clock(),
      forecastStation: forecast?.station,
      observationStation: observations?.station,
      forecast: forecast?.value,
      observations: observations?.value,
      overview: overview?.value,
      isStale: [forecast, observations, overview].any((l) => l?.stale ?? false),
      error: forecast?.value == null
          ? (forecast?.error ?? WeatherError.notFound)
          : errors.firstOrNull,
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
    bool force,
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
        force,
        (bytes) => MosmixClient.parseKmz(bytes, id),
      );
      if (loaded.value != null) {
        return _Loaded(match, loaded.value, loaded.stale, loaded.error);
      }
      lastError = loaded.error;
    }
    return lastError == null ? null : _Loaded(null, null, false, lastError);
  }

  Future<_Loaded<ObservationSeries>?> _loadObservations(
    WeatherLocation location,
    StationCatalog catalog,
    bool force,
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
        force,
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

  Future<_Loaded<StationOverview>> _loadOverview(
    String stationId,
    bool force,
  ) async {
    final loaded = await _cached(
      'overview:$stationId',
      WarnwetterClient.url([stationId]),
      overviewMaxAge,
      force,
      (bytes) => WarnwetterClient.parse(utf8.decode(bytes))[stationId],
      headers: const {'Accept': 'application/json'},
    );
    return _Loaded(null, loaded.value, loaded.stale, loaded.error);
  }

  Future<_CacheResult<T>> _cached<T>(
    String key,
    Uri uri,
    Duration maxAge,
    bool force,
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

    if (!force && cached != null && cached.isFresh(maxAge, now)) {
      final value = fromCache();
      if (value != null) return _CacheResult(value, false, null);
    }
    try {
      final bytes = await _fetch(uri, headers: headers);
      final value = parse(bytes);
      if (value == null) throw const WeatherException(WeatherError.invalidData);
      await _db.putCache(key, bytes, now);
      return _CacheResult(value, false, null);
    } on WeatherException catch (e) {
      debugLog('[WeatherRepository] $key failed: $e');
      final value = fromCache();
      return _CacheResult(value, value != null, e.error);
    }
  }
}

class _CacheResult<T> {
  const _CacheResult(this.value, this.stale, this.error);

  final T? value;
  final bool stale;
  final WeatherError? error;
}

class _Loaded<T> {
  const _Loaded(this.station, this.value, this.stale, this.error);

  final StationMatch? station;
  final T? value;
  final bool stale;
  final WeatherError? error;
}
