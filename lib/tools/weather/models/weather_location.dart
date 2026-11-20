class WeatherLocation {
  const WeatherLocation({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.isDeviceLocation = false,
    this.forecastStationId,
    this.observationStationId,
    this.sortOrder = 0,
  });

  factory WeatherLocation.fromMap(Map<String, Object?> map) => WeatherLocation(
    id: map['id'] as int?,
    name: map['name'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    elevation: (map['elevation'] as num?)?.toDouble(),
    isDeviceLocation: map['is_device'] == 1,
    forecastStationId: map['forecast_station'] as String?,
    observationStationId: map['observation_station'] as String?,
    sortOrder: map['sort_order'] as int? ?? 0,
  );

  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final double? elevation;

  /// Follows the device position instead of a fixed place.
  final bool isDeviceLocation;

  /// Pinned stations; null means the nearest one is picked automatically.
  final String? forecastStationId;
  final String? observationStationId;
  final int sortOrder;

  Map<String, Object?> toMap() => {
    'id': ?id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'elevation': elevation,
    'is_device': isDeviceLocation ? 1 : 0,
    'forecast_station': forecastStationId,
    'observation_station': observationStationId,
    'sort_order': sortOrder,
  };

  WeatherLocation copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    double? elevation,
    int? sortOrder,
  }) => WeatherLocation(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    elevation: elevation ?? this.elevation,
    isDeviceLocation: isDeviceLocation,
    forecastStationId: forecastStationId,
    observationStationId: observationStationId,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  WeatherLocation withStations({String? forecast, String? observation}) =>
      WeatherLocation(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        elevation: elevation,
        isDeviceLocation: isDeviceLocation,
        forecastStationId: forecast,
        observationStationId: observation,
        sortOrder: sortOrder,
      );

  WeatherLocation copyWithoutId() => WeatherLocation(
    name: name,
    latitude: latitude,
    longitude: longitude,
    elevation: elevation,
    isDeviceLocation: isDeviceLocation,
    forecastStationId: forecastStationId,
    observationStationId: observationStationId,
    sortOrder: sortOrder,
  );
}
