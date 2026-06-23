import 'dart:ui' show Offset;

/// A 2D point in world (canvas) coordinates. Wire form: `{x, y}`.
class SkPoint {
  final double x;
  final double y;

  const SkPoint(this.x, this.y);

  SkPoint.fromOffset(Offset o) : x = o.dx, y = o.dy;

  factory SkPoint.fromJson(Map<String, dynamic> j) =>
      SkPoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble());

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// Base for every drawable element. Field names + JSON keys mirror the
/// browser-toolkit `SketchElement` types so drawings sync losslessly.
///
/// Fields are mutable to allow in-place move/resize/recolor during interaction;
/// [clone] produces deep copies for the undo/redo history.
sealed class SketchElement {
  String id;
  String color;
  String? fillColor;
  double width;
  double rotation;
  String? brushStyle;

  SketchElement({
    required this.id,
    required this.color,
    this.fillColor,
    required this.width,
    this.rotation = 0,
    this.brushStyle,
  });

  String get type;

  SketchElement clone();

  /// Writes the shared base fields into [m], omitting absent/default values to
  /// keep the wire form identical to the browser tool's output.
  void _writeBase(Map<String, dynamic> m) {
    m['id'] = id;
    m['color'] = color;
    if (fillColor != null) m['fillColor'] = fillColor;
    m['width'] = width;
    if (rotation != 0) m['rotation'] = rotation;
    if (brushStyle != null) m['brushStyle'] = brushStyle;
  }

  Map<String, dynamic> toJson();

  factory SketchElement.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '') as String;
    final color = (j['color'] ?? '#000000') as String;
    final fillColor = j['fillColor'] as String?;
    final width = (j['width'] as num?)?.toDouble() ?? 2.0;
    final rotation = (j['rotation'] as num?)?.toDouble() ?? 0.0;
    final brushStyle = j['brushStyle'] as String?;
    final type = j['type'] as String?;

    SkPoint pt(String key) =>
        SkPoint.fromJson(Map<String, dynamic>.from(j[key] as Map));

    switch (type) {
      case 'freehand':
        return FreehandElement(
          id: id,
          color: color,
          fillColor: fillColor,
          width: width,
          rotation: rotation,
          brushStyle: brushStyle,
          points: ((j['points'] as List?) ?? const [])
              .map((p) => SkPoint.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList(),
        );
      case 'line':
      case 'rect':
      case 'ellipse':
      case 'triangle':
      case 'diamond':
      case 'hexagon':
      case 'arrow':
      case 'double-arrow':
      case 'speech-bubble':
      case 'checkmark':
        return ShapeElement(
          id: id,
          shapeType: type!,
          color: color,
          fillColor: fillColor,
          width: width,
          rotation: rotation,
          brushStyle: brushStyle,
          start: pt('start'),
          end: pt('end'),
          startSnap: _mapOrNull(j['startSnap']),
          endSnap: _mapOrNull(j['endSnap']),
          tailTip: j['tailTip'] == null
              ? null
              : SkPoint.fromJson(
                  Map<String, dynamic>.from(j['tailTip'] as Map),
                ),
        );
      case 'text':
        return TextElement(
          id: id,
          color: color,
          fillColor: fillColor,
          width: width,
          rotation: rotation,
          brushStyle: brushStyle,
          position: pt('position'),
          text: (j['text'] ?? '') as String,
          fontFamily: (j['fontFamily'] ?? 'sans-serif') as String,
          fontSize: (j['fontSize'] as num?)?.toDouble() ?? 24.0,
          fontWeight: (j['fontWeight'] ?? 'normal') as String,
          fontStyle: (j['fontStyle'] ?? 'normal') as String,
        );
      case 'image':
        return ImageElement(
          id: id,
          color: color,
          fillColor: fillColor,
          width: width,
          rotation: rotation,
          brushStyle: brushStyle,
          position: pt('position'),
          imageWidth: (j['imageWidth'] as num?)?.toDouble() ?? 0,
          imageHeight: (j['imageHeight'] as num?)?.toDouble() ?? 0,
          imageData: (j['imageData'] ?? '') as String,
          originalWidth: (j['originalWidth'] as num?)?.toDouble(),
          originalHeight: (j['originalHeight'] as num?)?.toDouble(),
        );
      case 'group':
        return GroupElement(
          id: id,
          color: color,
          fillColor: fillColor,
          width: width,
          rotation: rotation,
          brushStyle: brushStyle,
          elements: ((j['elements'] as List?) ?? const [])
              .map(
                (e) =>
                    SketchElement.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
        );
      default:
        return RawElement(Map<String, dynamic>.from(j));
    }
  }

  static Map<String, dynamic>? _mapOrNull(dynamic v) =>
      v == null ? null : Map<String, dynamic>.from(v as Map);
}

/// A freehand stroke (list of sampled points).
class FreehandElement extends SketchElement {
  List<SkPoint> points;

  FreehandElement({
    required super.id,
    required super.color,
    super.fillColor,
    required super.width,
    super.rotation,
    super.brushStyle,
    required this.points,
  });

  @override
  String get type => 'freehand';

  @override
  FreehandElement clone() => FreehandElement(
    id: id,
    color: color,
    fillColor: fillColor,
    width: width,
    rotation: rotation,
    brushStyle: brushStyle,
    points: points.map((p) => SkPoint(p.x, p.y)).toList(),
  );

  @override
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'type': type};
    _writeBase(m);
    m['points'] = points.map((p) => p.toJson()).toList();
    return m;
  }
}

/// All start/end based shapes (line, rect, ellipse, triangle, diamond, hexagon,
/// arrow, double-arrow, speech-bubble, checkmark). The concrete geometry is the
/// same `start`→`end` rectangle; the painter branches on [shapeType].
class ShapeElement extends SketchElement {
  final String shapeType;
  SkPoint start;
  SkPoint end;

  /// Connection metadata — preserved verbatim, not used interactively here.
  Map<String, dynamic>? startSnap;
  Map<String, dynamic>? endSnap;

  /// Speech-bubble tail tip (absolute). Null = default position.
  SkPoint? tailTip;

  ShapeElement({
    required super.id,
    required this.shapeType,
    required super.color,
    super.fillColor,
    required super.width,
    super.rotation,
    super.brushStyle,
    required this.start,
    required this.end,
    this.startSnap,
    this.endSnap,
    this.tailTip,
  });

  @override
  String get type => shapeType;

  @override
  ShapeElement clone() => ShapeElement(
    id: id,
    shapeType: shapeType,
    color: color,
    fillColor: fillColor,
    width: width,
    rotation: rotation,
    brushStyle: brushStyle,
    start: SkPoint(start.x, start.y),
    end: SkPoint(end.x, end.y),
    startSnap: startSnap == null ? null : Map<String, dynamic>.from(startSnap!),
    endSnap: endSnap == null ? null : Map<String, dynamic>.from(endSnap!),
    tailTip: tailTip == null ? null : SkPoint(tailTip!.x, tailTip!.y),
  );

  @override
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'type': type};
    _writeBase(m);
    m['start'] = start.toJson();
    m['end'] = end.toJson();
    if (startSnap != null) m['startSnap'] = startSnap;
    if (endSnap != null) m['endSnap'] = endSnap;
    if (tailTip != null) m['tailTip'] = tailTip!.toJson();
    return m;
  }
}

/// A text label anchored at its top-left [position].
class TextElement extends SketchElement {
  SkPoint position;
  String text;
  String fontFamily;
  double fontSize;
  String fontWeight; // 'normal' | 'bold'
  String fontStyle; // 'normal' | 'italic'

  TextElement({
    required super.id,
    required super.color,
    super.fillColor,
    required super.width,
    super.rotation,
    super.brushStyle,
    required this.position,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.fontStyle,
  });

  @override
  String get type => 'text';

  @override
  TextElement clone() => TextElement(
    id: id,
    color: color,
    fillColor: fillColor,
    width: width,
    rotation: rotation,
    brushStyle: brushStyle,
    position: SkPoint(position.x, position.y),
    text: text,
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
  );

  @override
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'type': type};
    _writeBase(m);
    m['position'] = position.toJson();
    m['text'] = text;
    m['fontFamily'] = fontFamily;
    m['fontSize'] = fontSize;
    m['fontWeight'] = fontWeight;
    m['fontStyle'] = fontStyle;
    return m;
  }
}

/// An embedded bitmap. [imageData] is a base64 data-URL string (inline, to
/// match the browser wire format).
class ImageElement extends SketchElement {
  SkPoint position;
  double imageWidth;
  double imageHeight;
  String imageData;
  double? originalWidth;
  double? originalHeight;

  ImageElement({
    required super.id,
    required super.color,
    super.fillColor,
    required super.width,
    super.rotation,
    super.brushStyle,
    required this.position,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageData,
    this.originalWidth,
    this.originalHeight,
  });

  @override
  String get type => 'image';

  @override
  ImageElement clone() => ImageElement(
    id: id,
    color: color,
    fillColor: fillColor,
    width: width,
    rotation: rotation,
    brushStyle: brushStyle,
    position: SkPoint(position.x, position.y),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    imageData: imageData,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
  );

  @override
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'type': type};
    _writeBase(m);
    m['position'] = position.toJson();
    m['imageWidth'] = imageWidth;
    m['imageHeight'] = imageHeight;
    m['imageData'] = imageData;
    if (originalWidth != null) m['originalWidth'] = originalWidth;
    if (originalHeight != null) m['originalHeight'] = originalHeight;
    return m;
  }
}

/// A group of nested elements (rendered recursively).
class GroupElement extends SketchElement {
  List<SketchElement> elements;

  GroupElement({
    required super.id,
    required super.color,
    super.fillColor,
    required super.width,
    super.rotation,
    super.brushStyle,
    required this.elements,
  });

  @override
  String get type => 'group';

  @override
  GroupElement clone() => GroupElement(
    id: id,
    color: color,
    fillColor: fillColor,
    width: width,
    rotation: rotation,
    brushStyle: brushStyle,
    elements: elements.map((e) => e.clone()).toList(),
  );

  @override
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'type': type};
    _writeBase(m);
    m['elements'] = elements.map((e) => e.toJson()).toList();
    return m;
  }
}

/// Fallback for element types this client does not understand. The raw map is
/// kept intact so it survives a sync round-trip; the painter skips it.
class RawElement extends SketchElement {
  final Map<String, dynamic> raw;

  RawElement(this.raw)
    : super(
        id: (raw['id'] ?? '') as String,
        color: (raw['color'] ?? '#000000') as String,
        fillColor: raw['fillColor'] as String?,
        width: (raw['width'] as num?)?.toDouble() ?? 1.0,
        rotation: (raw['rotation'] as num?)?.toDouble() ?? 0.0,
        brushStyle: raw['brushStyle'] as String?,
      );

  @override
  String get type => (raw['type'] ?? 'unknown') as String;

  @override
  RawElement clone() => RawElement(Map<String, dynamic>.from(raw));

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}
