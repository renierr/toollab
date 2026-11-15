import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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
    final boundary =
        frameKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.width <= 0) return false;
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
