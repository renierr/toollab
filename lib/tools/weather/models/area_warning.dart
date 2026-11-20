import 'weather_warning.dart';

/// A warning valid inside polygons, as the DWD nowcast publishes them.
class AreaWarning {
  const AreaWarning(this.warning, this.polygons);

  final WeatherWarning warning;

  /// Each polygon as alternating latitude/longitude values.
  final List<List<double>> polygons;

  bool contains(double lat, double lon) =>
      polygons.any((p) => _inside(p, lat, lon));

  static bool _inside(List<double> p, double lat, double lon) {
    var inside = false;
    final n = p.length ~/ 2;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final yi = p[i * 2], xi = p[i * 2 + 1];
      final yj = p[j * 2], xj = p[j * 2 + 1];
      if ((yi > lat) != (yj > lat) &&
          lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }
}
