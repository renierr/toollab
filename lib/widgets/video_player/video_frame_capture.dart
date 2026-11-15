import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';

import 'video_backend.dart';

/// Copies the current frame at the video's own size. A Flutter texture is read
/// back through [frameKey]'s repaint boundary: mpv's screenshot cannot convert
/// VA-API GPU frames.
Future<bool> copyVideoFrame({
  required VideoBackend backend,
  required GlobalKey frameKey,
  required double devicePixelRatio,
}) async {
  try {
    final native = await backend.nativeFrame();
    if (native != null) return await ClipboardHelper.copyImageBytes(native);
    final boundary = _boundary(frameKey);
    if (boundary == null) return false;
    final videoWidth = backend.state.value.videoWidth;
    final ratio = videoWidth != null
        ? videoWidth / boundary.size.width
        : devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return false;
      return await ClipboardHelper.copyImageBytes(
        png.buffer.asUint8List(),
        decoded: image,
      );
    } finally {
      image.dispose();
    }
  } catch (e) {
    errorLog('[VideoFrameCapture] Frame capture failed: $e');
    return false;
  }
}

/// A small JPEG of the current frame for the recent list.
Future<Uint8List?> captureVideoThumbnail({
  required VideoBackend backend,
  required GlobalKey frameKey,
  int width = 320,
}) async {
  try {
    final native = await backend.nativeFrame(width: width);
    if (native != null) return await compute(_pngToJpeg, native);
    final boundary = _boundary(frameKey);
    if (boundary == null) return null;
    final image = await boundary.toImage(
      pixelRatio: width / boundary.size.width,
    );
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return null;
      return await compute(_rgbaToJpeg, (
        rgba.buffer.asUint8List(),
        image.width,
        image.height,
      ));
    } finally {
      image.dispose();
    }
  } catch (e) {
    debugLog('[VideoFrameCapture] Thumbnail failed: $e');
    return null;
  }
}

RenderRepaintBoundary? _boundary(GlobalKey key) {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  return boundary != null && boundary.size.width > 0 ? boundary : null;
}

const int _jpegQuality = 75;

Uint8List? _pngToJpeg(Uint8List png) {
  final image = img.decodePng(png);
  return image == null ? null : img.encodeJpg(image, quality: _jpegQuality);
}

Uint8List _rgbaToJpeg((Uint8List, int, int) frame) {
  final (bytes, width, height) = frame;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: _jpegQuality);
}
