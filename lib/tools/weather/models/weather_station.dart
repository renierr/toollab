import 'dart:math' as math;

class WeatherStation {
  const WeatherStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.hasObservations,
  });

  factory WeatherStation.fromJsonRow(List<dynamic> row) => WeatherStation(
    id: row[0] as String,
    name: row[1] as String,
    latitude: (row[2] as num).toDouble(),
    longitude: (row[3] as num).toDouble(),
    elevation: (row[4] as num).toInt(),
    hasObservations: row[5] == 1,
  );

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int elevation;
  final bool hasObservations;

  double distanceKm(double lat, double lon) =>
      haversineKm(latitude, longitude, lat, lon);
}

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(a));
}
