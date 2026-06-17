import 'dart:math' as math;
import 'dart:ui';
import 'package:image/image.dart' as img;

class AutoCropDetector {
  AutoCropDetector._();

  /// Detects the 4 corners of a document page in the [source] image.
  /// Returns a list of 4 Offsets in order: Top-Left, Top-Right, Bottom-Right, Bottom-Left.
  /// If detection fails or document is not found, returns standard fallback corners
  /// (10% margin from the image edges).
  static List<Offset> detect(img.Image source, {int processDim = 300}) {
    final w = source.width;
    final h = source.height;

    // Fallback: 10% margin around the image boundaries
    final fallback = [
      Offset(w * 0.1, h * 0.1),
      Offset(w * 0.9, h * 0.1),
      Offset(w * 0.9, h * 0.9),
      Offset(w * 0.1, h * 0.9),
    ];

    // 1. Downscale the image to make detection extremely fast
    final scale = math.min(1.0, processDim / math.max(w, h));
    final dw = (w * scale).round();
    final dh = (h * scale).round();
    if (dw < 20 || dh < 20) return fallback;

    final downscaled = img.copyResize(source, width: dw, height: dh);

    // 2. Grayscale & compute average intensity
    final gray = List<int>.filled(dw * dh, 0);
    double sum = 0;
    for (int y = 0; y < dh; y++) {
      for (int x = 0; x < dw; x++) {
        final p = downscaled.getPixel(x, y);
        final val = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
        gray[y * dw + x] = val;
        sum += val;
      }
    }

    final double avg = sum / (dw * dh);
    // Papers are usually bright. Threshold at avg + 15 (bounded to reasonable values)
    final threshold = (avg + 15).clamp(60.0, 210.0);

    // 3. Find the largest connected white blob (document paper)
    final visited = List<bool>.filled(dw * dh, false);
    List<int> largestBlob = [];

    // Simple BFS/flood fill helper
    List<int> floodFill(int startX, int startY) {
      final blob = <int>[];
      final queue = <int>[startY * dw + startX];
      visited[startY * dw + startX] = true;

      int head = 0;
      while (head < queue.length) {
        final idx = queue[head++];
        blob.add(idx);

        final cx = idx % dw;
        final cy = idx ~/ dw;

        // Check 4-way neighbors
        final neighbors = [
          if (cx > 0) idx - 1,
          if (cx < dw - 1) idx + 1,
          if (cy > 0) idx - dw,
          if (cy < dh - 1) idx + dw,
        ];

        for (final nIdx in neighbors) {
          if (!visited[nIdx]) {
            if (gray[nIdx] > threshold) {
              visited[nIdx] = true;
              queue.add(nIdx);
            }
          }
        }
      }
      return blob;
    }

    for (int y = 0; y < dh; y++) {
      for (int x = 0; x < dw; x++) {
        final idx = y * dw + x;
        if (gray[idx] > threshold && !visited[idx]) {
          final blob = floodFill(x, y);
          if (blob.length > largestBlob.length) {
            largestBlob = blob;
          }
        }
      }
    }

    // If largest blob is too small (e.g. less than 8% of the image), we assume no document is found
    if (largestBlob.length < (dw * dh * 0.08)) {
      return fallback;
    }

    // 4. Find the extreme points of the largest blob
    // Top-Left: minimizes x + y
    // Top-Right: maximizes x - y
    // Bottom-Right: maximizes x + y
    // Bottom-Left: minimizes x - y
    double minSum = double.infinity;
    double maxSum = -double.infinity;
    double minDiff = double.infinity;
    double maxDiff = -double.infinity;

    int tlIdx = 0, trIdx = 0, brIdx = 0, blIdx = 0;

    for (final idx in largestBlob) {
      final x = (idx % dw).toDouble();
      final y = (idx ~/ dw).toDouble();

      final sumVal = x + y;
      final diffVal = x - y;

      if (sumVal < minSum) {
        minSum = sumVal;
        tlIdx = idx;
      }
      if (sumVal > maxSum) {
        maxSum = sumVal;
        brIdx = idx;
      }
      if (diffVal > maxDiff) {
        maxDiff = diffVal;
        trIdx = idx;
      }
      if (diffVal < minDiff) {
        minDiff = diffVal;
        blIdx = idx;
      }
    }

    final tlX = (tlIdx % dw).toDouble();
    final tlY = (tlIdx ~/ dw).toDouble();

    final trX = (trIdx % dw).toDouble();
    final trY = (trIdx ~/ dw).toDouble();

    final brX = (brIdx % dw).toDouble();
    final brY = (brIdx ~/ dw).toDouble();

    final blX = (blIdx % dw).toDouble();
    final blY = (blIdx ~/ dw).toDouble();

    // Scale back to original dimensions
    final double invScale = 1.0 / scale;
    return [
      Offset(
        (tlX * invScale).clamp(0.0, w.toDouble()),
        (tlY * invScale).clamp(0.0, h.toDouble()),
      ),
      Offset(
        (trX * invScale).clamp(0.0, w.toDouble()),
        (trY * invScale).clamp(0.0, h.toDouble()),
      ),
      Offset(
        (brX * invScale).clamp(0.0, w.toDouble()),
        (brY * invScale).clamp(0.0, h.toDouble()),
      ),
      Offset(
        (blX * invScale).clamp(0.0, w.toDouble()),
        (blY * invScale).clamp(0.0, h.toDouble()),
      ),
    ];
  }
}
