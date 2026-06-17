import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Supported document scanner filter types.
enum DocumentFilterType { none, grayscale, bw, clean }

class DocumentFilters {
  DocumentFilters._();

  /// Applies the selected filter to the [source] image.
  static img.Image apply(img.Image source, DocumentFilterType filter) {
    switch (filter) {
      case DocumentFilterType.none:
        return img.Image.from(source);
      case DocumentFilterType.grayscale:
        return _grayscale(source);
      case DocumentFilterType.bw:
        return _bw(source);
      case DocumentFilterType.clean:
        return _clean(source);
    }
  }

  static img.Image _grayscale(img.Image source) {
    final out = img.Image(
      width: source.width,
      height: source.height,
      numChannels: source.numChannels,
    );
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round()
            .clamp(0, 255);
        if (source.numChannels == 4) {
          out.setPixel(x, y, img.ColorRgba8(gray, gray, gray, pixel.a.toInt()));
        } else {
          out.setPixel(x, y, img.ColorRgb8(gray, gray, gray));
        }
      }
    }
    return out;
  }

  static img.Image _bw(img.Image source) {
    final out = img.Image(
      width: source.width,
      height: source.height,
      numChannels: source.numChannels,
    );
    for (int y = 0; y < source.height; y++) {
      for (int x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final gray = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        final val = gray > 128 ? 255 : 0;
        if (source.numChannels == 4) {
          out.setPixel(x, y, img.ColorRgba8(val, val, val, pixel.a.toInt()));
        } else {
          out.setPixel(x, y, img.ColorRgb8(val, val, val));
        }
      }
    }
    return out;
  }

  static img.Image _clean(img.Image source) {
    final w = source.width;
    final h = source.height;

    // 1. Calculate grayscale representation
    final gray = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = source.getPixel(x, y);
        gray[y * w + x] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round()
            .clamp(0, 255);
      }
    }

    // 2. Integral image for fast local mean
    // We use Float64List to prevent overflow in large image sums.
    final iw = w + 1;
    final ih = h + 1;
    final integral = Float64List(iw * ih);

    for (int y = 0; y < h; y++) {
      double rowSum = 0;
      for (int x = 0; x < w; x++) {
        rowSum += gray[y * w + x];
        integral[(y + 1) * iw + (x + 1)] = rowSum + integral[y * iw + (x + 1)];
      }
    }

    // 3. Local adaptive thresholding
    final out = img.Image(width: w, height: h, numChannels: source.numChannels);
    final radius = math.max(8, (math.min(w, h) * 0.04).round());

    for (int y = 0; y < h; y++) {
      final y0 = math.max(0, y - radius);
      final y1 = math.min(h, y + radius + 1);
      for (int x = 0; x < w; x++) {
        final x0 = math.max(0, x - radius);
        final x1 = math.min(w, x + radius + 1);
        final double area = ((x1 - x0) * (y1 - y0)).toDouble();

        final double sum =
            integral[y1 * iw + x1] -
            integral[y0 * iw + x1] -
            integral[y1 * iw + x0] +
            integral[y0 * iw + x0];

        final double localMean = sum / area;
        final double px = gray[y * w + x].toDouble();

        int val;
        if (px > localMean * 0.85) {
          val = 255; // background -> white
        } else {
          // enhance contrast for text
          val = ((px / (localMean * 0.85)) * 180).round().clamp(0, 255);
        }

        final origPixel = source.getPixel(x, y);
        if (source.numChannels == 4) {
          out.setPixel(
            x,
            y,
            img.ColorRgba8(val, val, val, origPixel.a.toInt()),
          );
        } else {
          out.setPixel(x, y, img.ColorRgb8(val, val, val));
        }
      }
    }
    return out;
  }
}
