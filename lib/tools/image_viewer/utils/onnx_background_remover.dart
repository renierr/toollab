import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// On-device background removal using the small U^2-Net (`u2netp`) ONNX model,
/// via `flutter_onnxruntime`. Works on every platform the plugin supports and
/// is used directly on Windows/Linux and as an ML-Kit-absent fallback on
/// Android. The model ships as a bundled asset.
///
/// Pipeline: resize to 320x320 + normalize (isolate) -> ORT inference (main
/// isolate, method channel) -> mask normalize/upscale + alpha composite
/// (isolate). Output is an RGBA cutout encoded as PNG.
const int kU2NetInputSize = 320;

// ImageNet normalization used by the U^2-Net training / rembg preprocessing.
const List<double> _mean = [0.485, 0.456, 0.406];
const List<double> _std = [0.229, 0.224, 0.225];

/// Builds the `[1, 3, 320, 320]` float input tensor (CHW) for u2netp.
Float32List preprocessU2NetTask(img.Image image) {
  final resized = img.copyResize(
    image,
    width: kU2NetInputSize,
    height: kU2NetInputSize,
    interpolation: img.Interpolation.linear,
  );

  // rembg normalizes by the max pixel value across the whole image, not 255.
  double maxVal = 1.0;
  for (int y = 0; y < kU2NetInputSize; y++) {
    for (int x = 0; x < kU2NetInputSize; x++) {
      final p = resized.getPixel(x, y);
      if (p.r > maxVal) maxVal = p.r.toDouble();
      if (p.g > maxVal) maxVal = p.g.toDouble();
      if (p.b > maxVal) maxVal = p.b.toDouble();
    }
  }

  const int plane = kU2NetInputSize * kU2NetInputSize;
  final out = Float32List(3 * plane);
  int idx = 0;
  for (int y = 0; y < kU2NetInputSize; y++) {
    for (int x = 0; x < kU2NetInputSize; x++) {
      final p = resized.getPixel(x, y);
      out[idx] = ((p.r / maxVal) - _mean[0]) / _std[0];
      out[plane + idx] = ((p.g / maxVal) - _mean[1]) / _std[1];
      out[2 * plane + idx] = ((p.b / maxVal) - _mean[2]) / _std[2];
      idx++;
    }
  }
  return out;
}

class U2NetPostprocessParams {
  final img.Image original;
  final Float32List mask;
  final int maskWidth;
  final int maskHeight;

  U2NetPostprocessParams({
    required this.original,
    required this.mask,
    required this.maskWidth,
    required this.maskHeight,
  });
}

/// Turns the raw saliency [mask] into a soft alpha channel over the original
/// image, returning a transparent-background RGBA cutout as PNG bytes.
Uint8List postprocessU2NetTask(U2NetPostprocessParams params) {
  final mask = params.mask;
  final mw = params.maskWidth;
  final mh = params.maskHeight;

  // Min-max normalize the mask to 0..1.
  double mi = double.infinity;
  double ma = -double.infinity;
  for (final v in mask) {
    if (v < mi) mi = v;
    if (v > ma) ma = v;
  }
  final range = ma - mi;
  final denom = range.abs() < 1e-8 ? 1.0 : range;

  final origW = params.original.width;
  final origH = params.original.height;

  final src =
      params.original.numChannels == 4 &&
          params.original.format == img.Format.uint8
      ? params.original
      : params.original.convert(numChannels: 4, format: img.Format.uint8);

  final out = img.Image(width: origW, height: origH, numChannels: 4);

  final double sx = origW > 1 ? (mw - 1) / (origW - 1) : 0.0;
  final double sy = origH > 1 ? (mh - 1) / (origH - 1) : 0.0;

  for (int y = 0; y < origH; y++) {
    final double fy = y * sy;
    final int y0 = fy.floor().clamp(0, mh - 1);
    final int y1 = (y0 + 1).clamp(0, mh - 1);
    final double dy = (fy - y0).clamp(0.0, 1.0);
    for (int x = 0; x < origW; x++) {
      final double fx = x * sx;
      final int x0 = fx.floor().clamp(0, mw - 1);
      final int x1 = (x0 + 1).clamp(0, mw - 1);
      final double dx = (fx - x0).clamp(0.0, 1.0);

      final v00 = mask[y0 * mw + x0];
      final v10 = mask[y0 * mw + x1];
      final v01 = mask[y1 * mw + x0];
      final v11 = mask[y1 * mw + x1];
      final top = v00 + (v10 - v00) * dx;
      final bot = v01 + (v11 - v01) * dx;
      final norm = (((top + (bot - top) * dy) - mi) / denom).clamp(0.0, 1.0);

      final p = src.getPixel(x, y);
      out.setPixelRgba(
        x,
        y,
        p.r.toInt(),
        p.g.toInt(),
        p.b.toInt(),
        (norm * 255).round(),
      );
    }
  }

  return Uint8List.fromList(img.encodePng(out));
}

class U2NetBackgroundRemover {
  static const String _assetKey = 'assets/models/u2netp.onnx';

  OrtSession? _session;
  Future<OrtSession>? _loading;

  Future<OrtSession> _ensureSession() async {
    if (_session != null) return _session!;
    _loading ??= OnnxRuntime().createSessionFromAsset(_assetKey);
    _session = await _loading;
    return _session!;
  }

  /// Runs the full cutout pipeline on [image], returning RGBA PNG bytes with a
  /// transparent background.
  Future<Uint8List> removeBackground(img.Image image) async {
    final session = await _ensureSession();

    final input = await compute(preprocessU2NetTask, image);
    final inputName = session.inputNames.first;
    final outputName = session.outputNames.first;

    final inputTensor = await OrtValue.fromList(input, [
      1,
      3,
      kU2NetInputSize,
      kU2NetInputSize,
    ]);

    Map<String, OrtValue> outputs;
    try {
      outputs = await session.run({inputName: inputTensor});
    } finally {
      await inputTensor.dispose();
    }

    final outValue = outputs[outputName] ?? outputs.values.first;
    final shape = outValue.shape;
    final flat = await outValue.asFlattenedList();
    final mask = Float32List(flat.length);
    for (int i = 0; i < flat.length; i++) {
      mask[i] = (flat[i] as num).toDouble();
    }
    for (final v in outputs.values) {
      await v.dispose();
    }

    final maskHeight = shape[shape.length - 2];
    final maskWidth = shape[shape.length - 1];

    return compute(
      postprocessU2NetTask,
      U2NetPostprocessParams(
        original: image,
        mask: mask,
        maskWidth: maskWidth,
        maskHeight: maskHeight,
      ),
    );
  }

  Future<void> dispose() async {
    final session = _session;
    _session = null;
    _loading = null;
    if (session != null) {
      try {
        await session.close();
      } catch (_) {}
    }
  }
}
