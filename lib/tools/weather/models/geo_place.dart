class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  factory GeoPlace.fromNominatim(Map<String, dynamic> json) {
    final display = json['display_name'] as String? ?? '';
    return GeoPlace(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : display.split(',').first,
      label: display,
      latitude: double.parse(json['lat'] as String),
      longitude: double.parse(json['lon'] as String),
    );
  }

  final String name;
  final String label;
  final double latitude;
  final double longitude;
}
