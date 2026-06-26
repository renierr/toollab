import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Rendering curve algorithm for a stroke.
enum CurveMode { fast, natural, draft, none }

/// Point-reduction (Ramer–Douglas–Peucker) aggressiveness.
enum RdpMode { none, low, medium, high }

/// Display-only background for the drawing canvas (not exported, not synced).
enum CanvasBackground { checkerboard, black, white }

CanvasBackground canvasBackgroundFromString(String? s) =>
    CanvasBackground.values.firstWhere(
      (b) => b.name == s,
      orElse: () => CanvasBackground.checkerboard,
    );

CurveMode curveModeFromString(String? s) => CurveMode.values.firstWhere(
  (m) => m.name == s,
  orElse: () => CurveMode.natural,
);

RdpMode rdpModeFromString(String? s) =>
    RdpMode.values.firstWhere((m) => m.name == s, orElse: () => RdpMode.none);

/// Epsilon used by the RDP simplifier for each mode (0 = disabled).
double rdpEpsilon(RdpMode mode) {
  switch (mode) {
    case RdpMode.low:
      return 0.5;
    case RdpMode.medium:
      return 1.0;
    case RdpMode.high:
      return 1.5;
    case RdpMode.none:
      return 0.0;
  }
}

/// A single captured input sample.
class SignaturePoint {
  final double x;
  final double y;

  /// Milliseconds since stroke capture start (may be fractional).
  final double timestamp;

  /// Normalized pen pressure in 0..1 (1.0 when the device reports none).
  final double pressure;

  const SignaturePoint({
    required this.x,
    required this.y,
    required this.timestamp,
    required this.pressure,
  });

  SignaturePoint copyWith({double? x, double? y}) => SignaturePoint(
    x: x ?? this.x,
    y: y ?? this.y,
    timestamp: timestamp,
    pressure: pressure,
  );

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'timestamp': timestamp,
    'pressure': pressure,
  };

  factory SignaturePoint.fromJson(Map<String, dynamic> j) => SignaturePoint(
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    timestamp: (j['timestamp'] as num?)?.toDouble() ?? 0,
    pressure: (j['pressure'] as num?)?.toDouble() ?? 1.0,
  );
}

/// All tunable parameters for capture, rendering and export.
///
/// Field names and defaults mirror the browser-toolkit `SignatureSettings`
/// wire format so records sync bidirectionally with the same backend.
class SignatureSettings {
  final String penColor;
  final double penWidth;
  final CurveMode curveMode;
  final RdpMode rdpMode;
  final int dpi;
  final double widthSmoothing;
  final double moveTolerance;
  final double minWidthFactor;
  final double maxWidthFactor;
  final double velocitySensitivity;
  final double pressureInfluence;
  final double velocityInfluence;

  const SignatureSettings({
    this.penColor = '#0B3D91',
    this.penWidth = 4,
    this.curveMode = CurveMode.natural,
    this.rdpMode = RdpMode.none,
    this.dpi = 96,
    this.widthSmoothing = 0.25,
    this.moveTolerance = 2,
    this.minWidthFactor = 0.15,
    this.maxWidthFactor = 2.0,
    this.velocitySensitivity = 0.85,
    this.pressureInfluence = 0.5,
    this.velocityInfluence = 0.9,
  });

  static const SignatureSettings defaults = SignatureSettings();

  SignatureSettings copyWith({
    String? penColor,
    double? penWidth,
    CurveMode? curveMode,
    RdpMode? rdpMode,
    int? dpi,
    double? widthSmoothing,
    double? moveTolerance,
    double? minWidthFactor,
    double? maxWidthFactor,
    double? velocitySensitivity,
    double? pressureInfluence,
    double? velocityInfluence,
  }) => SignatureSettings(
    penColor: penColor ?? this.penColor,
    penWidth: penWidth ?? this.penWidth,
    curveMode: curveMode ?? this.curveMode,
    rdpMode: rdpMode ?? this.rdpMode,
    dpi: dpi ?? this.dpi,
    widthSmoothing: widthSmoothing ?? this.widthSmoothing,
    moveTolerance: moveTolerance ?? this.moveTolerance,
    minWidthFactor: minWidthFactor ?? this.minWidthFactor,
    maxWidthFactor: maxWidthFactor ?? this.maxWidthFactor,
    velocitySensitivity: velocitySensitivity ?? this.velocitySensitivity,
    pressureInfluence: pressureInfluence ?? this.pressureInfluence,
    velocityInfluence: velocityInfluence ?? this.velocityInfluence,
  );

  Map<String, dynamic> toJson() => {
    'penColor': penColor,
    'penWidth': penWidth,
    'curveMode': curveMode.name,
    'rdpMode': rdpMode.name,
    'dpi': dpi,
    'widthSmoothing': widthSmoothing,
    'moveTolerance': moveTolerance,
    'minWidthFactor': minWidthFactor,
    'maxWidthFactor': maxWidthFactor,
    'velocitySensitivity': velocitySensitivity,
    'pressureInfluence': pressureInfluence,
    'velocityInfluence': velocityInfluence,
  };

  factory SignatureSettings.fromJson(
    Map<String, dynamic> j,
  ) => SignatureSettings(
    penColor: j['penColor'] as String? ?? defaults.penColor,
    penWidth: (j['penWidth'] as num?)?.toDouble() ?? defaults.penWidth,
    curveMode: curveModeFromString(j['curveMode'] as String?),
    rdpMode: rdpModeFromString(j['rdpMode'] as String?),
    dpi: (j['dpi'] as num?)?.toInt() ?? defaults.dpi,
    widthSmoothing:
        (j['widthSmoothing'] as num?)?.toDouble() ?? defaults.widthSmoothing,
    moveTolerance:
        (j['moveTolerance'] as num?)?.toDouble() ?? defaults.moveTolerance,
    minWidthFactor:
        (j['minWidthFactor'] as num?)?.toDouble() ?? defaults.minWidthFactor,
    maxWidthFactor:
        (j['maxWidthFactor'] as num?)?.toDouble() ?? defaults.maxWidthFactor,
    velocitySensitivity:
        (j['velocitySensitivity'] as num?)?.toDouble() ??
        defaults.velocitySensitivity,
    pressureInfluence:
        (j['pressureInfluence'] as num?)?.toDouble() ??
        defaults.pressureInfluence,
    velocityInfluence:
        (j['velocityInfluence'] as num?)?.toDouble() ??
        defaults.velocityInfluence,
  );
}

/// Parses a `#RRGGBB` (or `#RGB`) hex string into an opaque [Color].
Color colorFromHex(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) {
    h = h.split('').map((ch) => '$ch$ch').join();
  }
  final v = int.tryParse(h, radix: 16) ?? 0x0B3D91;
  return Color.fromARGB(255, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
}

/// Serializes an opaque [Color] to `#RRGGBB`.
String hexFromColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// A persisted signature, decoded from the local database.
class SignatureRecord {
  final String shortId;
  final Uint8List? image;
  final double width;
  final double height;

  /// Normalized stroke geometry (origin near 0,0), the source of truth.
  final List<List<SignaturePoint>> rawPaths;
  final SignatureSettings settings;
  final int createdAt;
  final int updatedAt;

  const SignatureRecord({
    required this.shortId,
    required this.image,
    required this.width,
    required this.height,
    required this.rawPaths,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Undoable canvas mutations.
sealed class SignatureCmd {
  const SignatureCmd();
}

class AddPathCmd extends SignatureCmd {
  final List<SignaturePoint> path;
  const AddPathCmd(this.path);
}

class ClearCmd extends SignatureCmd {
  final List<List<SignaturePoint>> prev;
  const ClearCmd(this.prev);
}

class ReplaceCmd extends SignatureCmd {
  final List<List<SignaturePoint>> prev;
  final List<List<SignaturePoint>> next;
  const ReplaceCmd(this.prev, this.next);
}
