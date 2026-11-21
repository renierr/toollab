import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/day_astronomy.dart';
import '../models/hourly_forecast.dart';
import '../models/local_station_manifest.dart';
import '../models/mosmix_forecast.dart';
import '../models/weather_condition.dart';
import '../models/weather_observation.dart';
import '../models/weather_warning.dart';
import 'weather_http.dart';

/// The station speaks a newer interface than this app reads.
class LocalStationVersionException implements Exception {
  const LocalStationVersionException(this.version);

  final int version;

  @override
  String toString() => 'LocalStationVersionException($version)';
}

/// Parsers for the local station interface in
/// `local_station/LOCAL_STATION_API.md`.
class LocalStationClient {
  LocalStationClient._();

  static const String apiName = 'toollab.weather-station';
  static const int supportedVersion = 1;
  static const String manifestFile = 'weather-station.json';
  static const Duration _minMaxAge = Duration(minutes: 1);

  /// Accepts a bare host ("192.168.1.50:8080", read as http), a base URL or
  /// the manifest URL itself; null when it is no usable http(s) address.
  static Uri? manifestUrl(String address) {
    var text = address.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return null;
    }
    if (uri.path.toLowerCase().endsWith('.json')) return uri;
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: '$path$manifestFile');
  }

  static LocalStationManifest parseManifest(Uint8List bytes, Uri url) {
    final json = _object(bytes);
    if (json['api'] != apiName) _invalid();
    final version = _int(json['version']);
    if (version == null) _invalid();
    if (version > supportedVersion) {
      throw LocalStationVersionException(version);
    }
    final station = json['station'];
    if (station is! Map<String, dynamic>) _invalid();
    final id = station['id'];
    final name = station['name'];
    final lat = _num(station['latitude']);
    final lon = _num(station['longitude']);
    if (id is! String ||
        name is! String ||
        name.trim().isEmpty ||
        lat == null ||
        lon == null ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      _invalid();
    }
    final sections = <LocalStationSection, LocalStationEndpoint>{};
    for (final section in LocalStationSection.values) {
      final entry = json[section.name];
      if (entry is! Map<String, dynamic>) continue;
      final path = entry['url'];
      final target = path is String ? Uri.tryParse(path) : null;
      if (target == null) continue;
      final seconds = _int(entry['refreshSeconds']);
      final fields = entry['fields'];
      sections[section] = LocalStationEndpoint(
        url: url.resolveUri(target),
        fields: {
          if (fields is List)
            for (final f in fields)
              if (f is String) f,
        },
        maxAge: seconds == null
            ? section.defaultMaxAge
            : Duration(seconds: math.max(seconds, _minMaxAge.inSeconds)),
      );
    }
    if (!sections.containsKey(LocalStationSection.observations) &&
        !sections.containsKey(LocalStationSection.forecast)) {
      _invalid();
    }
    return LocalStationManifest(
      url: url,
      version: version,
      id: id,
      name: name.trim(),
      latitude: lat,
      longitude: lon,
      elevation: _num(station['elevation']),
      sections: sections,
    );
  }

  /// Null without rows, so the DWD measurement steps in.
  static ObservationSeries? parseObservations(
    Uint8List bytes,
    String stationId,
    Set<String> fields,
  ) {
    final rows = [
      for (final row in _list(_object(bytes)['rows']))
        ?_observation(row, fields),
    ]..sort((a, b) => b.time.compareTo(a.time));
    if (rows.isEmpty) return null;
    return ObservationSeries(stationId: stationId, rows: rows);
  }

  static WeatherObservation? _observation(Object? row, Set<String> fields) {
    if (row is! Map<String, dynamic>) return null;
    final time = _time(row['time']);
    if (time == null) return null;
    double? n(String key) => fields.contains(key) ? _num(row[key]) : null;
    return WeatherObservation(
      time: time,
      temperature: n('temperature'),
      dewPoint: n('dewPoint'),
      humidity: n('humidity'),
      pressure: n('pressure'),
      windSpeed: n('windSpeed'),
      windDirection: n('windDirection'),
      windGust: n('windGust'),
      precipitation1h: n('precipitation1h'),
      precipitation24h: n('precipitation24h'),
      cloudCover: n('cloudCover'),
      visibility: n('visibility'),
      sunshineMinutes: n('sunshineMinutes'),
      fixedCondition: fields.contains('condition')
          ? _condition(row['condition'])
          : null,
    );
  }

  /// Null without hours, so the DWD forecast steps in.
  static MosmixForecast? parseForecast(
    Uint8List bytes,
    String stationId,
    Set<String> fields,
  ) {
    final json = _object(bytes);
    final hours = [for (final row in _list(json['hours'])) ?_hour(row, fields)]
      ..sort((a, b) => a.time.compareTo(b.time));
    if (hours.isEmpty) return null;
    return MosmixForecast(
      stationId: stationId,
      issueTime: _time(json['issued']) ?? hours.first.time,
      hours: hours,
    );
  }

  static HourlyForecast? _hour(Object? row, Set<String> fields) {
    if (row is! Map<String, dynamic>) return null;
    final time = _time(row['time']);
    if (time == null) return null;
    double? n(String key) => fields.contains(key) ? _num(row[key]) : null;
    final condition = fields.contains('condition')
        ? _condition(row['condition'])
        : null;
    return HourlyForecast(
      time: time,
      temperature: n('temperature'),
      dewPoint: n('dewPoint'),
      pressure: n('pressure'),
      windSpeed: n('windSpeed'),
      windDirection: n('windDirection'),
      windGust: n('windGust'),
      cloudCover: n('cloudCover'),
      precipitation: n('precipitation'),
      precipitationProbability: n('precipitationProbability'),
      sunshineMinutes: n('sunshineMinutes'),
      visibility: n('visibility'),
      fixedCondition: condition,
    );
  }

  static List<WeatherWarning> parseWarnings(Uint8List bytes) {
    final json = _object(bytes);
    if (json['warnings'] is! List) _invalid();
    return [for (final w in _list(json['warnings'])) ?_warning(w)];
  }

  static WeatherWarning? _warning(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final level = _int(json['level']);
    final start = _time(json['start']);
    final event = json['event'];
    if (id is! String || level == null || start == null || event is! String) {
      return null;
    }
    String text(String key) => json[key] is String ? json[key] as String : '';
    return WeatherWarning(
      id: id,
      type: 0,
      level: level.clamp(1, 4),
      start: start,
      end: _time(json['end']),
      event: event,
      headline: text('headline').isEmpty ? event : text('headline'),
      description: text('description'),
      instruction: text('instruction'),
    );
  }

  static List<DayAstronomy> parseDays(Uint8List bytes, Set<String> fields) {
    final days = <DayAstronomy>[];
    for (final row in _list(_object(bytes)['days'])) {
      if (row is! Map<String, dynamic>) continue;
      final date = row['date'] is String
          ? DateTime.tryParse(row['date'] as String)
          : null;
      if (date == null) continue;
      DateTime? t(String key) => fields.contains(key) ? _time(row[key]) : null;
      days.add(
        DayAstronomy(
          date: DateTime(date.year, date.month, date.day),
          sunrise: t('sunrise'),
          sunset: t('sunset'),
        ),
      );
    }
    return days;
  }

  static WeatherCondition? _condition(Object? name) =>
      name is String ? WeatherCondition.values.asNameMap()[name] : null;

  static Map<String, dynamic> _object(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      _invalid();
    }
    if (decoded is! Map<String, dynamic>) _invalid();
    return decoded;
  }

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static double? _num(Object? v) =>
      v is num && v.isFinite ? v.toDouble() : null;

  static int? _int(Object? v) => v is num && v.isFinite ? v.round() : null;

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;

  static Never _invalid() =>
      throw const WeatherException(WeatherError.invalidData);
}
