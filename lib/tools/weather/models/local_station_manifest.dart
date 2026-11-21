import 'weather_station.dart';

enum LocalStationSection {
  observations(Duration(minutes: 5)),
  forecast(Duration(hours: 1)),
  warnings(Duration(minutes: 5)),
  days(Duration(hours: 6));

  const LocalStationSection(this.defaultMaxAge);

  final Duration defaultMaxAge;
}

class LocalStationEndpoint {
  const LocalStationEndpoint({
    required this.url,
    required this.fields,
    required this.maxAge,
  });

  final Uri url;

  /// Declared field names; only these are read from the responses.
  final Set<String> fields;
  final Duration maxAge;
}

/// The `weather-station.json` of a local station server, see
/// `local_station/LOCAL_STATION_API.md`.
class LocalStationManifest {
  const LocalStationManifest({
    required this.url,
    required this.version,
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.elevation,
    required this.sections,
  });

  final Uri url;
  final int version;
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double? elevation;
  final Map<LocalStationSection, LocalStationEndpoint> sections;

  LocalStationEndpoint? operator [](LocalStationSection section) =>
      sections[section];

  WeatherStation get station => WeatherStation(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    elevation: elevation?.round() ?? 0,
    hasObservations: sections.containsKey(LocalStationSection.observations),
    isLocal: true,
  );
}
