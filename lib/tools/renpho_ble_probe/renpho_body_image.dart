import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'renpho_body_geometry.dart';
import 'renpho_body_metrics.dart';

const _ink = Color(0xFF23272E);
const _muted = Color(0xFF6B7280);

/// Renders the segment figure off-screen for print: same geometry as the
/// on-screen map, but on a light background and with the callouts drawn in
/// rather than laid out as widgets.
Future<Uint8List> renderRenphoBodyImage({
  required List<RenphoSegmentValues> segments,
  required String Function(RenphoSegment) name,
  Size size = const Size(330, 390),
  double pixelRatio = 3,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(pixelRatio);
  final figure = RenphoBodyGeometry.figureRect(size);

  canvas.drawPath(
    RenphoBodyGeometry.headAndNeck(figure),
    Paint()..color = _muted.withValues(alpha: 0.25),
  );

  final ordered = [
    ...segments.where((values) => values.segment == RenphoSegment.trunk),
    ...segments.where((values) => values.segment != RenphoSegment.trunk),
  ];
  for (final values in ordered) {
    final color = RenphoBodyGeometry.tint(values.muscleOfStandardPercent);
    final path = RenphoBodyGeometry.path(values.segment, figure);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
  }

  for (final values in segments) {
    final segment = values.segment;
    final color = RenphoBodyGeometry.tint(values.muscleOfStandardPercent);
    final callout = RenphoBodyGeometry.calloutRect(
      segment,
      size,
      RenphoBodyGeometry.calloutHeight,
    );
    final anchor = RenphoBodyGeometry.anchor(segment, figure);
    final end = segment == RenphoSegment.trunk
        ? Offset(callout.center.dx, callout.bottom)
        : Offset(
            RenphoBodyGeometry.onLeftSide(segment)
                ? callout.right
                : callout.left,
            callout.center.dy,
          );
    canvas.drawLine(
      anchor,
      end,
      Paint()
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.7),
    );
    canvas.drawCircle(anchor, 2.5, Paint()..color = color);

    canvas.drawRRect(
      RRect.fromRectAndRadius(callout, const Radius.circular(6)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(callout, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
    _text(
      canvas,
      name(segment),
      callout.left + 6,
      callout.top + 5,
      callout.width - 12,
      const TextStyle(color: _muted, fontSize: 9),
    );
    _text(
      canvas,
      '${values.muscleMassKg.toStringAsFixed(2)} kg',
      callout.left + 6,
      callout.top + 19,
      callout.width - 12,
      const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.bold),
    );
    _text(
      canvas,
      '${values.fatMassKg.toStringAsFixed(2)} kg',
      callout.left + 6,
      callout.top + 38,
      callout.width - 12,
      TextStyle(color: color, fontSize: 10),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * pixelRatio).round(),
    (size.height * pixelRatio).round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void _text(
  Canvas canvas,
  String text,
  double x,
  double y,
  double maxWidth,
  TextStyle style,
) {
  TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )
    ..layout(maxWidth: maxWidth)
    ..paint(canvas, Offset(x, y));
}
