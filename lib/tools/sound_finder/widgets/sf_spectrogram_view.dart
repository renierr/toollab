import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Scrolling spectrogram (waterfall): frequency on X (log), time on Y (newest
/// at the top), magnitude as color. Complements the line spectrum for spotting
/// intermittent or drifting tones over time — the Spectroid lower panel.
///
/// Each incoming frame is pre-binned to a fixed [_cols]-wide log-frequency row
/// spanning the full [20 Hz .. fullMaxHz] range, so zooming/panning is a cheap
/// source-rectangle crop (log axis → linear column index) with no re-analysis.
class SfSpectrogramView extends StatefulWidget {
  final Float64List magnitudes;
  final double binHz;
  final double minHz; // visible range low edge
  final double maxHz; // visible range high edge
  final double fullMaxHz; // full source range high edge (Nyquist)

  const SfSpectrogramView({
    super.key,
    required this.magnitudes,
    required this.binHz,
    required this.minHz,
    required this.maxHz,
    required this.fullMaxHz,
  });

  @override
  State<SfSpectrogramView> createState() => _SfSpectrogramViewState();
}

class _SfSpectrogramViewState extends State<SfSpectrogramView> {
  static const int _cols = 480;
  static const int _rows = 180;
  static const int _rowBytes = _cols * 4;
  static const double _fullMinHz = 20;
  static const double _dbFloor = -100;
  static const double _dbCeil = -20;

  // Magma colormap stops (RGB), dark → bright, lerped per magnitude.
  static const List<List<int>> _magma = [
    [0, 0, 4],
    [59, 15, 112],
    [140, 41, 129],
    [222, 73, 104],
    [254, 159, 109],
    [252, 253, 191],
  ];

  final Uint8List _pixels = Uint8List(_cols * _rows * 4);
  ui.Image? _image;
  bool _decoding = false;

  @override
  void initState() {
    super.initState();
    for (int p = 0; p < _cols * _rows; p++) {
      _writeColor(0, p * 4);
    }
    _pushRow();
  }

  @override
  void didUpdateWidget(SfSpectrogramView old) {
    super.didUpdateWidget(old);
    if (!identical(old.magnitudes, widget.magnitudes)) _pushRow();
  }

  void _writeColor(double t, int offset) {
    final double x = (t * (_magma.length - 1)).clamp(
      0.0,
      (_magma.length - 1).toDouble(),
    );
    final int i = x.floor().clamp(0, _magma.length - 2);
    final double f = x - i;
    final List<int> a = _magma[i];
    final List<int> b = _magma[i + 1];
    _pixels[offset] = (a[0] + (b[0] - a[0]) * f).round();
    _pixels[offset + 1] = (a[1] + (b[1] - a[1]) * f).round();
    _pixels[offset + 2] = (a[2] + (b[2] - a[2]) * f).round();
    _pixels[offset + 3] = 255;
  }

  void _pushRow() {
    final Float64List mags = widget.magnitudes;
    if (mags.length < 2) return;

    // Scroll down one row (backward copy keeps overlapping ranges intact).
    for (int r = _rows - 1; r > 0; r--) {
      _pixels.setRange(
        r * _rowBytes,
        (r + 1) * _rowBytes,
        _pixels,
        (r - 1) * _rowBytes,
      );
    }

    final double logMin = math.log(_fullMinHz);
    final double logSpan = math.log(widget.fullMaxHz) - logMin;
    final int maxBin = mags.length - 1;
    for (int c = 0; c < _cols; c++) {
      final double fLo = math.exp(logMin + logSpan * c / _cols);
      final double fHi = math.exp(logMin + logSpan * (c + 1) / _cols);
      int lo = (fLo / widget.binHz).floor().clamp(1, maxBin);
      int hi = (fHi / widget.binHz).ceil().clamp(lo, maxBin);
      double peak = 0;
      for (int i = lo; i <= hi; i++) {
        if (mags[i] > peak) peak = mags[i];
      }
      final double db = peak > 1e-9
          ? 20 * (math.log(peak) / math.ln10)
          : _dbFloor;
      final double norm = ((db - _dbFloor) / (_dbCeil - _dbFloor)).clamp(
        0.0,
        1.0,
      );
      _writeColor(norm, c * 4);
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
    return CustomPaint(
      size: Size.infinite,
      painter: _SpectrogramPainter(
        image: _image,
        minHz: widget.minHz,
        maxHz: widget.maxHz,
        fullMaxHz: widget.fullMaxHz,
      ),
    );
  }
}

class _SpectrogramPainter extends CustomPainter {
  final ui.Image? image;
  final double minHz;
  final double maxHz;
  final double fullMaxHz;

  static const double _fullMinHz = 20;

  _SpectrogramPainter({
    required this.image,
    required this.minHz,
    required this.maxHz,
    required this.fullMaxHz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? img = image;
    if (img == null) return;
    final double logMin = math.log(_fullMinHz);
    final double logSpan = math.log(fullMaxHz) - logMin;
    double colFor(double hz) => ((math.log(hz) - logMin) / logSpan * img.width)
        .clamp(0.0, img.width.toDouble());
    final double sl = colFor(minHz);
    final double sr = math.max(sl + 1, colFor(maxHz));
    canvas.drawImageRect(
      img,
      Rect.fromLTRB(sl, 0, sr, img.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) =>
      !identical(old.image, image) ||
      old.minHz != minHz ||
      old.maxHz != maxHz ||
      old.fullMaxHz != fullMaxHz;
}
