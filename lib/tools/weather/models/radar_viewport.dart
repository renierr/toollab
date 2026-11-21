import 'dart:math' as math;
import 'dart:ui';

import '../api/dwd_radar.dart';

/// A map view in Web Mercator metres. Rects use left/top as min x/y and
/// right/bottom as max x/y, i.e. y grows north, unlike screen space.
class RadarViewport {
  const RadarViewport({
    required this.centerX,
    required this.centerY,
    required this.resolution,
    required this.size,
  });

  /// [anchorY] is where the place sits vertically, as a share of the height
  /// from the top; views with controls at the bottom pass less than half.
  factory RadarViewport.around(
    double lat,
    double lon,
    Size size, {
    double resolution = 1200,
    double anchorY = .5,
  }) {
    // Clamp the zoom first so the anchor offset uses the final resolution.
    final res = RadarViewport(
      centerX: 0,
      centerY: 0,
      resolution: resolution,
      size: size,
    ).clamped().resolution;
    return RadarViewport(
      centerX: Mercator.x(lon),
      centerY: Mercator.y(lat) + (anchorY - .5) * size.height * res,
      resolution: res,
      size: size,
    ).clamped();
  }

  /// Closer than this the 1 km radar cells only turn into big blobs.
  static const double minResolution = 220;

  final double centerX;
  final double centerY;

  /// Metres per logical pixel.
  final double resolution;
  final Size size;

  double get maxResolution => math.max(
    Mercator.coverage.width / math.max(size.width, 1),
    Mercator.coverage.height / math.max(size.height, 1),
  );

  Rect get bounds => Rect.fromLTRB(
    centerX - size.width / 2 * resolution,
    centerY - size.height / 2 * resolution,
    centerX + size.width / 2 * resolution,
    centerY + size.height / 2 * resolution,
  );

  Offset toScreen(double x, double y) => Offset(
    (x - centerX) / resolution + size.width / 2,
    (centerY - y) / resolution + size.height / 2,
  );

  Offset toScreenLatLon(double lat, double lon) =>
      toScreen(Mercator.x(lon), Mercator.y(lat));

  Rect rectToScreen(Rect bbox) {
    final topLeft = toScreen(bbox.left, bbox.bottom);
    final bottomRight = toScreen(bbox.right, bbox.top);
    return Rect.fromPoints(topLeft, bottomRight);
  }

  RadarViewport copyWith({
    double? centerX,
    double? centerY,
    double? resolution,
    Size? size,
  }) => RadarViewport(
    centerX: centerX ?? this.centerX,
    centerY: centerY ?? this.centerY,
    resolution: resolution ?? this.resolution,
    size: size ?? this.size,
  );

  RadarViewport panBy(Offset screenDelta) => copyWith(
    centerX: centerX - screenDelta.dx * resolution,
    centerY: centerY + screenDelta.dy * resolution,
  ).clamped();

  /// Keeps the map point under [focal] fixed while zooming by [factor] (>1 = in).
  RadarViewport zoomAt(double factor, Offset focal) {
    final next = (resolution / factor).clamp(minResolution, maxResolution);
    final dx = focal.dx - size.width / 2;
    final dy = focal.dy - size.height / 2;
    final fx = centerX + dx * resolution;
    final fy = centerY - dy * resolution;
    return copyWith(
      centerX: fx - dx * next,
      centerY: fy + dy * next,
      resolution: next,
    ).clamped();
  }

  RadarViewport clamped() {
    final c = Mercator.coverage;
    final res = resolution.clamp(
      minResolution,
      math.max(minResolution, maxResolution),
    );
    return RadarViewport(
      centerX: centerX.clamp(c.left, c.right),
      centerY: centerY.clamp(c.top, c.bottom),
      resolution: res.toDouble(),
      size: size,
    );
  }
}
