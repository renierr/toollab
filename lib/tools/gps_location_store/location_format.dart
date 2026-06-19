import 'saved_location.dart';

String formatCoordinates(double lat, double lon) =>
    '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';

String _two(int v) => v.toString().padLeft(2, '0');

/// Absolute local timestamp, e.g. `2026-06-19 14:05`.
String formatTimestamp(SavedLocation location) {
  final d = location.createdAtDate;
  return '${d.year}-${_two(d.month)}-${_two(d.day)} '
      '${_two(d.hour)}:${_two(d.minute)}';
}
