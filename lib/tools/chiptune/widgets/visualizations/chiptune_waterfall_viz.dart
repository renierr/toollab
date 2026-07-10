import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'chiptune_viz_data.dart';

/// Scrolling spectrogram (waterfall) visualization.
class ChiptuneWaterfallViz extends StatefulWidget {
  final VizData? data;
  const ChiptuneWaterfallViz({super.key, this.data});

  @override
  State<ChiptuneWaterfallViz> createState() => _ChiptuneWaterfallVizState();
}

class _ChiptuneWaterfallVizState extends State<ChiptuneWaterfallViz> {
  static const int _cols = 320;
  static const int _rows = 120;
  static const int _rowBytes = _cols * 4;

  // Rate limits the scroll speed so it is smooth and readable (approx 15 updates per second)
  static const double _rowIntervalSecs = 0.064;

  // Custom colormap stops (RGB) mapping to the chiptune player aesthetics.
  static const List<List<int>> _colormap = [
    [18, 14, 32], // ChiptuneColors.visualizerBg (dark)
    [48, 25, 87], // Dark purple
    [124, 77, 255], // ChiptuneColors.visBar (purple-blue)
    [224, 92, 255], // ChiptuneColors.visPeak (magenta)
    [255, 171, 0], // Amber/orange highlights
    [255, 255, 255], // White peaks
  ];

  final Uint8List _pixels = Uint8List(_cols * _rows * 4);
  ui.Image? _image;
  bool _decoding = false;
  double _accumulatedTime = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize with background color
    for (int p = 0; p < _cols * _rows; p++) {
      _writeColor(0.0, p * 4);
    }
  }

  @override
  void didUpdateWidget(ChiptuneWaterfallViz oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.data;
    if (data != null && oldWidget.data != data) {
      _accumulatedTime += data.deltaTime;
      if (_accumulatedTime >= _rowIntervalSecs) {
        _accumulatedTime =
            0.0; // Reset and cap to prevent stampedes after pause
        _pushRow(data.freq);
      }
    }
  }

  void _writeColor(double norm, int offset) {
    final double x = (norm * (_colormap.length - 1)).clamp(
      0.0,
      (_colormap.length - 1).toDouble(),
    );
    final int i = x.floor().clamp(0, _colormap.length - 2);
    final double f = x - i;
    final List<int> a = _colormap[i];
    final List<int> b = _colormap[i + 1];
    _pixels[offset] = (a[0] + (b[0] - a[0]) * f).round();
    _pixels[offset + 1] = (a[1] + (b[1] - a[1]) * f).round();
    _pixels[offset + 2] = (a[2] + (b[2] - a[2]) * f).round();
    _pixels[offset + 3] = 255;
  }

  void _pushRow(List<double> freq) {
    if (freq.isEmpty) return;

    // Scroll down one row: move rows [0.._rows-2] to [1.._rows-1]
    for (int r = _rows - 1; r > 0; r--) {
      _pixels.setRange(
        r * _rowBytes,
        (r + 1) * _rowBytes,
        _pixels,
        (r - 1) * _rowBytes,
      );
    }

    // Logarithmic mapping bounds in Hz
    const double minHz = 20.0;
    const double maxHz = 16000.0;
    final double logMin = math.log(minHz);
    final double logSpan = math.log(maxHz) - logMin;
    const double nyquist = 22050.0;
    final double hzPerBin = nyquist / freq.length;

    // Populate the new top row (r = 0) using logarithmic frequency mapping + peak sampling
    for (int c = 0; c < _cols; c++) {
      final double fLo = math.exp(logMin + logSpan * c / _cols);
      final double fHi = math.exp(logMin + logSpan * (c + 1) / _cols);

      // Start clamp at 1 to ignore the DC offset / subsonic rumble at bin 0
      int lo = (fLo / hzPerBin).floor().clamp(1, freq.length - 1);
      int hi = (fHi / hzPerBin).ceil().clamp(lo, freq.length - 1);

      // Find the peak magnitude in this column's frequency span (prevents aliasing)
      double peak = 0.0;
      for (int i = lo; i <= hi; i++) {
        if (freq[i] > peak) {
          peak = freq[i];
        }
      }

      // SoLoud's native C++ engine (calcFFT in analyzer.cpp) already:
      //  1. Applies Blackman windowing
      //  2. Applies frequency-dependent scaling
      //  3. Converts linear magnitudes to logarithmic scale (2 * log10(mag + 1))
      //  4. Clamps the result to [0.0, 1.0]
      //
      // Doing another "20 * log10(mag)" here was double-log-scaling the data,
      // compressing the dynamic range and turning it mostly solid yellow.
      // We map the native log-scaled peak directly to the colormap.
      final double normMag = peak.clamp(0.0, 1.0);

      _writeColor(normMag, c * 4);
    }

    _decode();
  }

  void _decode() {
    if (_decoding) return;
    _decoding = true;
    ui.decodeImageFromPixels(_pixels, _cols, _rows, ui.PixelFormat.rgba8888, (
      ui.Image img,
    ) {
      _decoding = false;
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = img;
      });
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(painter: _WaterfallPainter(img), size: Size.infinite),
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  final ui.Image image;
  const _WaterfallPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_WaterfallPainter oldDelegate) =>
      !identical(oldDelegate.image, image);
}
