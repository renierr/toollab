import 'signature_geometry.dart';
import 'signature_models.dart';

/// Result of shifting strokes so their bounding box sits at the origin.
class NormalizedSignature {
  final List<List<SignaturePoint>> paths;
  final double width;
  final double height;
  const NormalizedSignature(this.paths, this.width, this.height);
}

/// Translates all strokes so the drawing's top-left bounding corner becomes
/// `(pad, pad)`, returning the logical canvas size needed to contain it.
NormalizedSignature normalizeSignature(
  List<List<SignaturePoint>> paths,
  double penWidth,
) {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = -double.infinity;
  double maxY = -double.infinity;

  for (final stroke in paths) {
    for (final p in stroke) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
  }

  if (minX == double.infinity) {
    return const NormalizedSignature([], 1, 1);
  }

  final pad = penWidth * 2;
  final width = (maxX - minX) + pad * 2;
  final height = (maxY - minY) + pad * 2;

  final shifted = paths
      .map(
        (stroke) => stroke
            .map((p) => p.copyWith(x: p.x - minX + pad, y: p.y - minY + pad))
            .toList(),
      )
      .toList();

  return NormalizedSignature(shifted, width, height);
}

/// Builds a self-contained SVG document for the (already normalized) strokes.
///
/// Stroke width is constant (`penWidth`) in vector output; per-segment width
/// dynamics are only applied in the rasterized PNG.
String generateSignatureSvg(
  List<List<SignaturePoint>> paths,
  double width,
  double height,
  SignatureSettings s,
) {
  final color = s.penColor.startsWith('#') ? s.penColor : '#${s.penColor}';
  final w = width.toStringAsFixed(2);
  final h = height.toStringAsFixed(2);

  final sb = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" '
      'viewBox="0 0 $w $h">',
    );

  for (final stroke in paths) {
    if (stroke.isEmpty) continue;
    if (stroke.length == 1) {
      final p = stroke.first;
      sb.writeln(
        '<circle cx="${_n(p.x)}" cy="${_n(p.y)}" r="${_n(s.penWidth / 2)}" '
        'fill="$color"/>',
      );
      continue;
    }
    final d = _strokeToPathData(stroke, s.curveMode);
    if (d.isEmpty) continue;
    sb.writeln(
      '<path d="$d" fill="none" stroke="$color" '
      'stroke-width="${_n(s.penWidth)}" stroke-linecap="round" '
      'stroke-linejoin="round"/>',
    );
  }

  sb.writeln('</svg>');
  return sb.toString();
}

String _strokeToPathData(List<SignaturePoint> pts, CurveMode mode) {
  final sb = StringBuffer('M ${_n(pts[0].x)} ${_n(pts[0].y)}');
  switch (mode) {
    case CurveMode.natural:
      for (int i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i == 0 ? 0 : i - 1];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = pts[i + 2 >= pts.length ? pts.length - 1 : i + 2];
        final cp = catmullRomControls(p0, p1, p2, p3);
        sb.write(
          ' C ${_n(cp.c1x)} ${_n(cp.c1y)} ${_n(cp.c2x)} ${_n(cp.c2y)} '
          '${_n(p2.x)} ${_n(p2.y)}',
        );
      }
      break;
    case CurveMode.fast:
      for (int i = 1; i < pts.length; i++) {
        final p1 = pts[i - 1];
        final p2 = pts[i];
        final midX = (p1.x + p2.x) / 2;
        final midY = (p1.y + p2.y) / 2;
        sb.write(' Q ${_n(p1.x)} ${_n(p1.y)} ${_n(midX)} ${_n(midY)}');
      }
      sb.write(' L ${_n(pts.last.x)} ${_n(pts.last.y)}');
      break;
    case CurveMode.draft:
    case CurveMode.none:
      for (int i = 1; i < pts.length; i++) {
        sb.write(' L ${_n(pts[i].x)} ${_n(pts[i].y)}');
      }
      break;
  }
  return sb.toString();
}

String _n(double v) => v.toStringAsFixed(2);
