import 'saved_location.dart';

String formatCoordinates(double lat, double lon) =>
    '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
}

/// Maps a bearing in degrees to an 8-point compass index (0 = N, 1 = NE, …).
int compassIndex(double bearing) {
  final normalized = (bearing % 360 + 360) % 360;
  return (normalized / 45).round() % 8;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// Absolute local timestamp, e.g. `2026-06-19 14:05`.
String formatTimestamp(SavedLocation location) {
  final d = location.createdAtDate;
  return '${d.year}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';
}
