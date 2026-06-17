import 'dart:math' as math;
import 'dart:ui';
import 'package:image/image.dart' as img;

/// Linear algebra and homography helper for perspective warping.
class PerspectiveWarp {
  PerspectiveWarp._();

  /// Solves an 8x8 system using Gaussian elimination.
  /// The matrix should be of size 8x9 (augmented matrix).
  static List<double> _solve8x8(List<List<double>> matrix) {
    const int n = 8;
    for (int i = 0; i < n; i++) {
      int max = i;
      for (int j = i + 1; j < n; j++) {
        if (matrix[j][i].abs() > matrix[max][i].abs()) {
          max = j;
        }
      }
      final temp = matrix[i];
      matrix[i] = matrix[max];
      matrix[max] = temp;

      if (matrix[i][i].abs() < 1e-9) {
        // Singular matrix, return empty coefficients or fallback
        return List<double>.filled(n, 0);
      }

      for (int j = i + 1; j < n; j++) {
        final c = -matrix[j][i] / matrix[i][i];
        for (int k = i; k <= n; k++) {
          if (i == k) {
            matrix[j][k] = 0;
          } else {
            matrix[j][k] += c * matrix[i][k];
          }
        }
      }
    }

    final x = List<double>.filled(n, 0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = matrix[i][n] / matrix[i][i];
      for (int j = i - 1; j >= 0; j--) {
        matrix[j][n] -= matrix[j][i] * x[i];
      }
    }
    return x;
  }

  /// Computes the perspective projection matrix mapping [src] (destination rectified rect points)
  /// to [dst] (original image crop corners).
  static List<double> getPerspectiveTransform(
    List<Offset> src,
    List<Offset> dst,
  ) {
    final matrix = List.generate(8, (_) => List<double>.filled(9, 0));
    for (int i = 0; i < 4; i++) {
      matrix[i * 2] = [
        src[i].dx,
        src[i].dy,
        1.0,
        0.0,
        0.0,
        0.0,
        -src[i].dx * dst[i].dx,
        -src[i].dy * dst[i].dx,
        dst[i].dx,
      ];
      matrix[i * 2 + 1] = [
        0.0,
        0.0,
        0.0,
        src[i].dx,
        src[i].dy,
        1.0,
        -src[i].dx * dst[i].dy,
        -src[i].dy * dst[i].dy,
        dst[i].dy,
      ];
    }
    return _solve8x8(matrix);
  }

  /// Warps the perspective of [source] to a rectified rectangle determined by the 4 [corners].
  /// [corners] must be in order: Top-Left, Top-Right, Bottom-Right, Bottom-Left.
  /// If the target dimensions exceed [maxDimension], it will scale the output size down.
  static img.Image warp(
    img.Image source,
    List<Offset> corners, {
    int maxDimension = 1600,
  }) {
    if (corners.length != 4) return source;

    // Calculate dimensions of the output image based on the hypotenuses of the crop edges
    final w1 = math.sqrt(
      math.pow(corners[1].dx - corners[0].dx, 2) +
          math.pow(corners[1].dy - corners[0].dy, 2),
    );
    final w2 = math.sqrt(
      math.pow(corners[2].dx - corners[3].dx, 2) +
          math.pow(corners[2].dy - corners[3].dy, 2),
    );
    final h1 = math.sqrt(
      math.pow(corners[3].dx - corners[0].dx, 2) +
          math.pow(corners[3].dy - corners[0].dy, 2),
    );
    final h2 = math.sqrt(
      math.pow(corners[2].dx - corners[1].dx, 2) +
          math.pow(corners[2].dy - corners[1].dy, 2),
    );

    double targetW = math.max(w1, w2);
    double targetH = math.max(h1, h2);

    if (targetW < 10) targetW = 10;
    if (targetH < 10) targetH = 10;

    // Constrain to maximum resolution
    final scale = math.min(1.0, maxDimension / math.max(targetW, targetH));
    final int width = (targetW * scale).round();
    final int height = (targetH * scale).round();

    final destRect = [
      Offset(0, 0),
      Offset(width.toDouble(), 0),
      Offset(width.toDouble(), height.toDouble()),
      Offset(0, height.toDouble()),
    ];

    final transform = getPerspectiveTransform(destRect, corners);
    if (transform.every((val) => val == 0)) {
      // Failed to compute transform, return original or copy
      return source;
    }

    final t0 = transform[0], t1 = transform[1], t2 = transform[2];
    final t3 = transform[3], t4 = transform[4], t5 = transform[5];
    final t6 = transform[6], t7 = transform[7];

    final outImage = img.Image(
      width: width,
      height: height,
      numChannels: source.numChannels,
    );
    final srcW = source.width;
    final srcH = source.height;

    for (int v = 0; v < height; v++) {
      final rv1 = t1 * v + t2;
      final rv4 = t4 * v + t5;
      final rv7 = t7 * v + 1.0;

      for (int u = 0; u < width; u++) {
        final den = t6 * u + rv7;
        if (den.abs() < 1e-9) continue;
        final invDen = 1.0 / den;
        final x = (t0 * u + rv1) * invDen;
        final y = (t3 * u + rv4) * invDen;

        final ix = x.floor();
        final iy = y.floor();

        if (ix >= 0 && ix < srcW - 1 && iy >= 0 && iy < srcH - 1) {
          final fx = x - ix;
          final fy = y - iy;

          // Bilinear interpolation weights
          final w00 = (1.0 - fx) * (1.0 - fy);
          final w10 = fx * (1.0 - fy);
          final w01 = (1.0 - fx) * fy;
          final w11 = fx * fy;

          final p00 = source.getPixel(ix, iy);
          final p10 = source.getPixel(ix + 1, iy);
          final p01 = source.getPixel(ix, iy + 1);
          final p11 = source.getPixel(ix + 1, iy + 1);

          final r = p00.r * w00 + p10.r * w10 + p01.r * w01 + p11.r * w11;
          final g = p00.g * w00 + p10.g * w10 + p01.g * w01 + p11.g * w11;
          final b = p00.b * w00 + p10.b * w10 + p01.b * w01 + p11.b * w11;

          if (source.numChannels == 4) {
            final a = p00.a * w00 + p10.a * w10 + p01.a * w01 + p11.a * w11;
            outImage.setPixel(
              u,
              v,
              img.ColorRgba8(r.round(), g.round(), b.round(), a.round()),
            );
          } else {
            outImage.setPixel(
              u,
              v,
              img.ColorRgb8(r.round(), g.round(), b.round()),
            );
          }
        }
      }
    }

    return outImage;
  }
}
