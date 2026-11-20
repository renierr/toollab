import 'dart:typed_data';

class WeatherCacheEntry {
  const WeatherCacheEntry({
    required this.key,
    required this.body,
    required this.fetchedAt,
  });

  factory WeatherCacheEntry.fromMap(Map<String, Object?> map) =>
      WeatherCacheEntry(
        key: map['key'] as String,
        body: map['body'] as Uint8List,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          map['fetched_at'] as int,
        ),
      );

  final String key;
  final Uint8List body;
  final DateTime fetchedAt;

  bool isFresh(Duration maxAge, DateTime now) =>
      now.difference(fetchedAt) < maxAge;
}
