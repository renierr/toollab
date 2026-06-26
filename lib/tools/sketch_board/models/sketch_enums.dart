import 'package:flutter/material.dart';

import '../sketch_board_colors.dart';

/// Interaction / drawing modes. Wire names use hyphens (e.g. `double-arrow`),
/// so [wire] / [toolModeFromWire] bridge the enum and the JSON form.
enum ToolMode {
  pan,
  select,
  freehand,
  line,
  rect,
  ellipse,
  triangle,
  diamond,
  hexagon,
  arrow,
  doubleArrow,
  speechBubble,
  checkmark,
  text,
  image;

  /// JSON / browser-toolkit identifier for this mode.
  String get wire {
    switch (this) {
      case ToolMode.doubleArrow:
        return 'double-arrow';
      case ToolMode.speechBubble:
        return 'speech-bubble';
      default:
        return name;
    }
  }
}

ToolMode toolModeFromWire(String? s) {
  switch (s) {
    case 'double-arrow':
      return ToolMode.doubleArrow;
    case 'speech-bubble':
      return ToolMode.speechBubble;
    default:
      return ToolMode.values.firstWhere(
        (m) => m.name == s,
        orElse: () => ToolMode.pan,
      );
  }
}

/// Bitmap format the board can be exported to.
enum ExportFormat {
  png,
  jpeg,
  webp;

  String get extension {
    return switch (this) {
      ExportFormat.jpeg => 'jpg',
      ExportFormat.webp => 'webp',
      ExportFormat.png => 'png',
    };
  }

  String get mimeType {
    return switch (this) {
      ExportFormat.jpeg => 'image/jpeg',
      ExportFormat.webp => 'image/webp',
      ExportFormat.png => 'image/png',
    };
  }

  String get label {
    return switch (this) {
      ExportFormat.jpeg => 'JPEG',
      ExportFormat.webp => 'WebP',
      ExportFormat.png => 'PNG',
    };
  }

  /// Whether a quality setting is meaningful (PNG, WebP are lossless).
  bool get isLossy => this == ExportFormat.jpeg;
}

/// How a marquee selection captures elements.
enum SelectionType { box, lasso }

/// Stroke rendering style.
enum BrushStyle { normal, shaky, natural }

BrushStyle brushStyleFromWire(String? s) => BrushStyle.values.firstWhere(
  (b) => b.name == s,
  orElse: () => BrushStyle.normal,
);

/// Display-only canvas backdrop (not part of element geometry).
enum CanvasBackground { checkerboard, white, black }

CanvasBackground canvasBackgroundFromString(String? s) =>
    CanvasBackground.values.firstWhere(
      (b) => b.name == s,
      orElse: () => CanvasBackground.checkerboard,
    );

/// Parses a `#RGB`, `#RRGGBB`, or `#RRGGBBAA` hex string into a [Color].
/// Returns `null` for `transparent`/empty so callers can treat it as "no fill".
Color? colorFromHexOrNull(String? hex) {
  if (hex == null) return null;
  final t = hex.trim();
  if (t.isEmpty || t.toLowerCase() == 'transparent') return null;
  var h = t.replaceAll('#', '');
  if (h.length == 3) {
    h = h.split('').map((ch) => '$ch$ch').join();
  }
  if (h.length != 6 && h.length != 8) return null;
  if (h.length == 6) {
    h = 'FF$h';
  } else if (h.length == 8) {
    // Hex is RRGGBBAA from the web; reorder to AARRGGBB for dart:ui.
    final rgb = h.substring(0, 6);
    final a = h.substring(6, 8);
    h = '$a$rgb';
  }
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Like [colorFromHexOrNull] but falls back to opaque black.
Color colorFromHex(String? hex) =>
    colorFromHexOrNull(hex) ?? SketchBoardColors.black;

/// Serializes an opaque [Color] to `#RRGGBB`.
String hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Serializes a [Color] to `#RRGGBB` (opaque) or `#RRGGBBAA` (translucent).
String hexFromColorWithAlpha(Color color) {
  final argb = color.toARGB32();
  final a = (argb >> 24) & 0xFF;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  if (a == 0xFF) return '#${rgb.toUpperCase()}';
  final aa = a.toRadixString(16).padLeft(2, '0');
  return '#${rgb.toUpperCase()}${aa.toUpperCase()}';
}
