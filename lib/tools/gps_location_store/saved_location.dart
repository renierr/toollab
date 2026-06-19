import 'location_source.dart';

/// A single stored GPS location entry.
class SavedLocation {
  final int id;
  final double latitude;
  final double longitude;

  /// Horizontal accuracy in meters, when known (`null` for IP-based fixes).
  final double? accuracy;
  final String description;
  final LocationSource source;
  final int createdAt;

  const SavedLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.description,
    required this.source,
    required this.createdAt,
  });

  factory SavedLocation.fromMap(Map<String, dynamic> map) {
    return SavedLocation(
      id: map['id'] as int,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      description: map['description'] as String? ?? '',
      source: LocationSource.fromDb(map['source'] as String?),
      createdAt: map['created_at'] as int? ?? 0,
    );
  }

  DateTime get createdAtDate => DateTime.fromMillisecondsSinceEpoch(createdAt);
}
