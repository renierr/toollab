import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/weather_station.dart';

class StationMatch {
  const StationMatch(this.station, this.distanceKm);

  final WeatherStation station;
  final double distanceKm;
}

class StationCatalog {
  StationCatalog(this.stations) : _byId = {for (final s in stations) s.id: s};

  factory StationCatalog.fromJson(String json) => StationCatalog([
    for (final row in jsonDecode(json) as List<dynamic>)
      WeatherStation.fromJsonRow(row as List<dynamic>),
  ]);

  static const String assetPath = 'assets/weather/stations.json';
  static Future<StationCatalog>? _loading;

  static Future<StationCatalog> load([AssetBundle? bundle]) =>
      _loading ??= (bundle ?? rootBundle)
          .loadString(assetPath)
          .then(StationCatalog.fromJson);

  final List<WeatherStation> stations;
  final Map<String, WeatherStation> _byId;

  WeatherStation? byId(String id) => _byId[id];

  /// Ranks by distance plus 1 km per 50 m of height difference, so a summit
  /// station does not win for a valley town. Without [elevation] the median
  /// height of the closest stations stands in for the place.
  List<StationMatch> nearest(
    double lat,
    double lon, {
    double? elevation,
    bool observationsOnly = false,
    int limit = 8,
    double maxDistanceKm = 150,
  }) {
    final nearby = <StationMatch>[];
    for (final s in stations) {
      if ((s.latitude - lat).abs() > 2 || (s.longitude - lon).abs() > 3) {
        continue;
      }
      final d = s.distanceKm(lat, lon);
      if (d <= maxDistanceKm) nearby.add(StationMatch(s, d));
    }
    final reference = elevation ?? _estimateElevation(nearby);
    final matches = <({StationMatch match, double score})>[];
    for (final m in nearby) {
      if (observationsOnly && !m.station.hasObservations) continue;
      final penalty = reference == null
          ? 0.0
          : (m.station.elevation - reference).abs() / 50;
      matches.add((match: m, score: m.distanceKm + penalty));
    }
    matches.sort((a, b) => a.score.compareTo(b.score));
    return [for (final m in matches.take(limit)) m.match];
  }

  static double? _estimateElevation(List<StationMatch> nearby) {
    if (nearby.isEmpty) return null;
    final closest = [...nearby]
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    final heights = [for (final m in closest.take(5)) m.station.elevation]
      ..sort();
    return heights[heights.length ~/ 2].toDouble();
  }

  List<WeatherStation> search(String query, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final starts = <WeatherStation>[];
    final contains = <WeatherStation>[];
    for (final s in stations) {
      final name = s.name.toLowerCase();
      if (name.startsWith(q) || s.id.toLowerCase() == q) {
        starts.add(s);
      } else if (name.contains(q)) {
        contains.add(s);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }
}
