import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/sketch_element.dart';
import '../models/sketch_enums.dart';
import 'element_bounds.dart';
import 'element_renderer.dart';

/// Decodes a base64 data-URL (or bare base64) string into a [ui.Image].
Future<ui.Image?> decodeImageData(String data) async {
  if (data.isEmpty) return null;
  var b64 = data;
  final comma = data.indexOf(',');
  if (data.startsWith('data:') && comma != -1) b64 = data.substring(comma + 1);
  try {
    final bytes = base64Decode(b64);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (e) {
    debugPrint('[SketchExport] image decode failed: $e');
    return null;
  }
}

/// Decodes every [ImageElement] in [elements] (recursing groups) into a map
/// keyed by `imageData`, for synchronous lookup during rendering/export.
Future<Map<String, ui.Image>> decodeImages(List<SketchElement> elements) async {
  final out = <String, ui.Image>{};
  Future<void> walk(List<SketchElement> els) async {
    for (final el in els) {
      if (el is ImageElement && el.imageData.isNotEmpty) {
        if (out.containsKey(el.imageData)) continue;
        final img = await decodeImageData(el.imageData);
        if (img != null) out[el.imageData] = img;
      } else if (el is GroupElement) {
        await walk(el.elements);
      }
    }
  }

  await walk(elements);
  return out;
}

/// Renders [elements] to a cropped bitmap in [format]. Returns null when there
/// is nothing to draw. [scale] supersamples for crispness; [background] fills
/// behind content. [quality] (1–100) only applies to lossy formats (JPEG);
/// JPEG has no alpha, so a transparent [background] is forced to white.
Future<Uint8List?> renderImage(
  List<SketchElement> elements, {
  ExportFormat format = ExportFormat.png,
  int quality = 92,
  double scale = 2.0,
  Color? background,
}) async {
  final bounds = sceneBounds(elements, padding: 8);
  if (bounds == null) return null;

  final images = await decodeImages(elements);
  ui.Image? resolver(String d) => images[d];

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);
  canvas.translate(-bounds.left, -bounds.top);

  final bg = format == ExportFormat.jpeg
      ? (background ?? const Color(0xFFFFFFFF))
      : background;
  if (bg != null) {
    canvas.drawRect(bounds, Paint()..color = bg);
  }
  for (final el in elements) {
    drawElement(canvas, el, imageResolver: resolver);
  }

  final picture = recorder.endRecording();
  final w = math.max(1, (bounds.width * scale).ceil());
  final h = math.max(1, (bounds.height * scale).ceil());
  final image = await picture.toImage(w, h);

  Uint8List? out;
  if (format == ExportFormat.png) {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    out = data?.buffer.asUint8List();
  } else {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data != null) {
      final raw = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: data.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      out = img.encodeJpg(raw, quality: quality.clamp(1, 100));
    }
  }

  image.dispose();
  picture.dispose();
  for (final i in images.values) {
    i.dispose();
  }
  return out;
}

/// Renders [elements] to a cropped PNG (lossless). Convenience wrapper around
/// [renderImage] for the clipboard / share paths that always want PNG.
Future<Uint8List?> renderPng(
  List<SketchElement> elements, {
  double scale = 2.0,
  Color? background,
}) => renderImage(elements, scale: scale, background: background);

/// Renders a fitted ~320x200 thumbnail PNG for the gallery. Returns empty bytes
/// when there is nothing to draw.
Future<Uint8List> makeThumbnail(List<SketchElement> elements) async {
  const tw = 320.0, th = 200.0, pad = 12.0;
  final bounds = sceneBounds(elements);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (bounds != null && bounds.width > 0 && bounds.height > 0) {
    final images = await decodeImages(elements);
    ui.Image? resolver(String d) => images[d];

    final s = math.min(
      (tw - pad * 2) / bounds.width,
      (th - pad * 2) / bounds.height,
    );
    final drawW = bounds.width * s;
    final drawH = bounds.height * s;
    canvas.translate((tw - drawW) / 2, (th - drawH) / 2);
    canvas.scale(s);
    canvas.translate(-bounds.left, -bounds.top);
    for (final el in elements) {
      drawElement(canvas, el, imageResolver: resolver);
    }
    for (final img in images.values) {
      img.dispose();
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(tw.toInt(), th.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

/// Builds the lightweight stats summary stored with a saved drawing.
({int count, List<String> colors}) summarize(List<SketchElement> elements) {
  int count = 0;
  final colors = <String>{};
  void walk(List<SketchElement> els) {
    for (final el in els) {
      if (el is GroupElement) {
        walk(el.elements);
      } else if (el is! RawElement) {
        count++;
        colors.add(el.color);
      }
    }
  }

  walk(elements);
  return (count: count, colors: colors.take(12).toList());
}
