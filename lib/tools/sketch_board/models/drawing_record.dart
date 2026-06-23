import 'dart:typed_data';

import 'sketch_element.dart';

/// Pan/zoom state of the canvas. Wire form: `{x, y, scale}`.
class ViewportState {
  final double x;
  final double y;
  final double scale;

  const ViewportState({this.x = 0, this.y = 0, this.scale = 1});

  factory ViewportState.fromJson(Map<String, dynamic> j) => ViewportState(
    x: (j['x'] as num?)?.toDouble() ?? 0,
    y: (j['y'] as num?)?.toDouble() ?? 0,
    scale: (j['scale'] as num?)?.toDouble() ?? 1,
  );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'scale': scale};
}

/// Lightweight summary stored alongside a drawing (matches the browser tool).
class DrawingMeta {
  final int elementCount;
  final List<String> colors;
  final String lastTool;
  final String? background;

  const DrawingMeta({
    required this.elementCount,
    required this.colors,
    required this.lastTool,
    this.background,
  });

  factory DrawingMeta.fromJson(Map<String, dynamic> j) => DrawingMeta(
    elementCount: (j['elementCount'] as num?)?.toInt() ?? 0,
    colors:
        (j['colors'] as List?)?.map((c) => c.toString()).toList() ?? const [],
    lastTool: (j['lastTool'] ?? 'pan') as String,
    background: j['background'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'elementCount': elementCount,
    'colors': colors,
    'lastTool': lastTool,
    if (background != null) 'background': background,
  };
}

/// A persisted drawing decoded from the local database.
///
/// [thumbnail] is stored locally as a PNG BLOB; on the sync wire it travels as a
/// `thumbnailDataUrl` data-URL string to match the browser-toolkit format.
class DrawingRecord {
  final String shortId;
  final String name;
  final ViewportState viewport;
  final List<SketchElement> elements;
  final Uint8List? thumbnail;
  final DrawingMeta meta;
  final int createdAt;
  final int updatedAt;

  const DrawingRecord({
    required this.shortId,
    required this.name,
    required this.viewport,
    required this.elements,
    required this.thumbnail,
    required this.meta,
    required this.createdAt,
    required this.updatedAt,
  });
}
