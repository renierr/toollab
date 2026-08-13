import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/tools/sketch_board/models/sketch_element.dart';

/// Longest edge an image element keeps while it is being edited. Purely a
/// memory guard: the canvas can still be zoomed and the element resized, so the
/// bound is generous.
const int sketchImageEditMaxEdge = 4096;

/// Longest edge an image element is stored at. A drawing is pushed through sync
/// as one JSON record carrying its images base64-inline, so a phone photo left
/// at full resolution puts a single record over the backend's request ceiling.
const int sketchImageStoreMaxEdge = 2048;

class _ResampleRequest {
  final Uint8List bytes;
  final int maxEdge;

  const _ResampleRequest(this.bytes, this.maxEdge);
}

/// Re-encodes [bytes] so its longest edge is at most [maxEdge], or returns null
/// when it already fits and the original bytes should be kept as they are.
///
/// Runs off the UI isolate: decoding a full-resolution photo janks the canvas.
Future<Uint8List?> downscaleSketchImage(Uint8List bytes, int maxEdge) =>
    compute(_resample, _ResampleRequest(bytes, maxEdge));

Uint8List? _resample(_ResampleRequest request) {
  final decoded = img.decodeImage(request.bytes);
  if (decoded == null) return null;

  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest <= request.maxEdge) return null;

  final resized = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: request.maxEdge)
      : img.copyResize(decoded, height: request.maxEdge);

  // Photographs dominate this path and re-encode far smaller as JPEG, but an
  // image carrying transparency has to stay PNG or the alpha turns black.
  return decoded.hasAlpha
      ? img.encodePng(resized)
      : img.encodeJpg(resized, quality: 85);
}

/// Mime type [downscaleSketchImage] produces for a source that had [hasAlpha].
String downscaledMime(Uint8List encoded) =>
    // JPEG starts with FF D8 FF; anything else this produces is PNG.
    encoded.length >= 3 &&
        encoded[0] == 0xFF &&
        encoded[1] == 0xD8 &&
        encoded[2] == 0xFF
    ? 'image/jpeg'
    : 'image/png';

/// Builds the inline data URL an [ImageElement] stores.
String sketchImageDataUrl(Uint8List bytes, String mime) =>
    'data:$mime;base64,${base64Encode(bytes)}';

/// Returns a copy of [elements] whose images are bounded by
/// [sketchImageStoreMaxEdge], leaving the originals untouched so the canvas
/// keeps the resolution it was edited at until the drawing is reopened.
Future<List<SketchElement>> boundImagesForStorage(
  List<SketchElement> elements,
) async {
  final out = <SketchElement>[];
  for (final el in elements) {
    if (el is GroupElement) {
      out.add(
        GroupElement(
          id: el.id,
          color: el.color,
          fillColor: el.fillColor,
          width: el.width,
          rotation: el.rotation,
          brushStyle: el.brushStyle,
          elements: await boundImagesForStorage(el.elements),
        ),
      );
      continue;
    }
    if (el is! ImageElement || el.imageData.isEmpty) {
      out.add(el);
      continue;
    }
    final bounded = await _boundDataUrl(el.imageData);
    if (bounded == null) {
      out.add(el);
      continue;
    }
    out.add(el.clone()..imageData = bounded);
  }
  return out;
}

Future<String?> _boundDataUrl(String dataUrl) async {
  final comma = dataUrl.indexOf(',');
  if (!dataUrl.startsWith('data:') || comma == -1) return null;
  Uint8List bytes;
  try {
    bytes = base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
  final resized = await downscaleSketchImage(bytes, sketchImageStoreMaxEdge);
  if (resized == null) return null;
  return sketchImageDataUrl(resized, downscaledMime(resized));
}
