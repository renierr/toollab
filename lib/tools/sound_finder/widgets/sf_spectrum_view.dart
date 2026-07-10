import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../sf_format.dart';
import '../sound_finder_colors.dart';

/// Spectroid-style spectrum: the full FFT magnitude spectrum rendered on a
/// logarithmic frequency axis. The visible range ([minHz]..[maxHz]) can be
/// narrowed by callers to zoom in; each pixel column shows the strongest bin
/// in its slice so fine peaks stay visible at any zoom level.
///
/// Fills its parent — wrap in a sized box (compact) or [Expanded] (fullscreen).
class SfSpectrumView extends StatefulWidget {
  final Float64List magnitudes;
  final double binHz;
  final double peakFreqHz;
  final double minHz;
  final double maxHz;

  /// Draw frequency + dB grid lines and labels (used in the enlarged view).
  final bool showAxes;

  /// Overlay a slowly-decaying max-hold trace to reveal intermittent tones.
  final bool maxHold;

  const SfSpectrumView({
    super.key,
    required this.magnitudes,
    required this.binHz,
    required this.peakFreqHz,
    this.minHz = 20,
    this.maxHz = 22050,
    this.showAxes = false,
    this.maxHold = false,
  });

  @override
  State<SfSpectrumView> createState() => _SfSpectrumViewState();
}

class _SfSpectrumViewState extends State<SfSpectrumView> {
  static const double _decay = 0.90;
  Float64List? _hold;

  void _updateHold() {
    if (!widget.maxHold) {
      _hold = null;
      return;
    }
    final Float64List mags = widget.magnitudes;
    Float64List hold = _hold ?? Float64List(mags.length);
    if (hold.length != mags.length) hold = Float64List(mags.length);
    for (int i = 0; i < mags.length; i++) {
      final double decayed = hold[i] * _decay;
      hold[i] = mags[i] > decayed ? mags[i] : decayed;
    }
    _hold = hold;
  }

  @override
  void initState() {
    super.initState();
    _updateHold();
  }

  @override
  void didUpdateWidget(SfSpectrumView old) {
    super.didUpdateWidget(old);
    if (!identical(old.magnitudes, widget.magnitudes) ||
        old.maxHold != widget.maxHold) {
      _updateHold();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _SpectrumPainter(
        magnitudes: widget.magnitudes,
        hold: widget.maxHold ? _hold : null,
        binHz: widget.binHz,
        peakFreqHz: widget.peakFreqHz,
        minHz: widget.minHz,
        maxHz: widget.maxHz,
        showAxes: widget.showAxes,
        textColor: theme.colorScheme.onSurfaceVariant,
        gridColor: theme.colorScheme.outline.withValues(alpha: 0.18),
        markerColor: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final Float64List magnitudes;
  final Float64List? hold;
  final double binHz;
  final double peakFreqHz;
  final double minHz;
  final double maxHz;
  final bool showAxes;
  final Color textColor;
  final Color gridColor;
  final Color markerColor;

  static const double _dbFloor = -100;
  static const double _dbCeil = 0;

  // Grid lines drawn on the log axis; the labelled subset follows a 1-3-10
  // pattern so the axis stays readable when zoomed.
  static const List<double> _freqTicks = [
    20, 30, 50, 100, 200, 300, 500, //
    1000, 2000, 3000, 5000, 10000, 20000,
  ];
  static const List<double> _labelledTicks = [
    30,
    100,
    300,
    1000,
    3000,
    10000,
    20000,
  ];

  _SpectrumPainter({
    required this.magnitudes,
    required this.hold,
    required this.binHz,
    required this.peakFreqHz,
    required this.minHz,
    required this.maxHz,
    required this.showAxes,
    required this.textColor,
    required this.gridColor,
    required this.markerColor,
  });

  double _logMin = 0;
  double _logSpan = 1;

  double _xForFreq(double hz, double width) =>
      (math.log(hz) - _logMin) / _logSpan * width;

  double _freqForX(double x, double width) =>
      math.exp(_logMin + _logSpan * x / width);

  double _normForBinRange(int lo, int hi) {
    double peak = 0;
    for (int i = lo; i <= hi; i++) {
      if (magnitudes[i] > peak) peak = magnitudes[i];
    }
    return _normForMag(peak);
  }

  double _holdNormForBinRange(int lo, int hi) {
    final Float64List h = hold!;
    double peak = 0;
    for (int i = lo; i <= hi; i++) {
      if (h[i] > peak) peak = h[i];
    }
    return _normForMag(peak);
  }

  double _normForMag(double mag) {
    final double db = mag > 1e-9 ? 20 * (math.log(mag) / math.ln10) : _dbFloor;
    return ((db - _dbFloor) / (_dbCeil - _dbFloor)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (magnitudes.length < 2) return;
    _logMin = math.log(minHz);
    _logSpan = math.log(maxHz) - _logMin;
    final int maxBin = magnitudes.length - 1;

    if (showAxes) _paintGrid(canvas, size);

    // Sample one column per pixel; each column reports the loudest bin in its
    // frequency slice so no peak is skipped when many bins fall on one column.
    final int cols = size.width.ceil();
    final List<Offset> line = [];
    final List<Offset> holdLine = [];
    for (int c = 0; c <= cols; c++) {
      final double x = c.toDouble();
      final double fLo = _freqForX(x, size.width);
      final double fHi = _freqForX(x + 1, size.width);
      int lo = (fLo / binHz).floor();
      int hi = (fHi / binHz).ceil();
      lo = lo.clamp(1, maxBin);
      hi = hi.clamp(lo, maxBin);
      final double y = size.height * (1 - _normForBinRange(lo, hi));
      line.add(Offset(x, y));
      if (hold != null) {
        holdLine.add(
          Offset(x, size.height * (1 - _holdNormForBinRange(lo, hi))),
        );
      }
    }

    _paintFill(canvas, size, line);
    if (hold != null) _paintHold(canvas, holdLine);
    _paintPeak(canvas, size);
  }

  void _paintFill(Canvas canvas, Size size, List<Offset> line) {
    final Path fill = Path()..moveTo(0, size.height);
    for (final Offset p in line) {
      fill.lineTo(p.dx, p.dy);
    }
    fill
      ..lineTo(size.width, size.height)
      ..close();
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          SoundFinderColors.spectrumLow.withValues(alpha: 0.15),
          SoundFinderColors.spectrumLow.withValues(alpha: 0.55),
          SoundFinderColors.spectrumHigh.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fill, fillPaint);

    final Path stroke = Path();
    for (int i = 0; i < line.length; i++) {
      if (i == 0) {
        stroke.moveTo(line[i].dx, line[i].dy);
      } else {
        stroke.lineTo(line[i].dx, line[i].dy);
      }
    }
    canvas.drawPath(
      stroke,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = SoundFinderColors.spectrumHigh,
    );
  }

  void _paintHold(Canvas canvas, List<Offset> holdLine) {
    final Path path = Path();
    for (int i = 0; i < holdLine.length; i++) {
      if (i == 0) {
        path.moveTo(holdLine[i].dx, holdLine[i].dy);
      } else {
        path.lineTo(holdLine[i].dx, holdLine[i].dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = SoundFinderColors.violet.withValues(alpha: 0.75),
    );
  }

  void _paintGrid(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (double db = _dbFloor + 20; db < _dbCeil; db += 20) {
      final double y =
          size.height * (1 - (db - _dbFloor) / (_dbCeil - _dbFloor));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      _label(canvas, '${db.toStringAsFixed(0)} dB', Offset(4, y + 2), 9);
    }

    for (final double hz in _freqTicks) {
      if (hz < minHz || hz > maxHz) continue;
      final double x = _xForFreq(hz, size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      if (_labelledTicks.contains(hz)) {
        _label(canvas, formatHz(hz), Offset(x + 3, size.height - 14), 9);
      }
    }
  }

  void _paintPeak(Canvas canvas, Size size) {
    if (peakFreqHz < minHz || peakFreqHz > maxHz) return;
    final double x = _xForFreq(peakFreqHz, size.width).clamp(0.0, size.width);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = markerColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );
    _label(
      canvas,
      formatHz(peakFreqHz),
      Offset((x + 4).clamp(0.0, size.width - 52), 3),
      11,
      color: markerColor,
      bold: true,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double fontSize, {
    Color? color,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? textColor,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      !identical(old.magnitudes, magnitudes) ||
      !identical(old.hold, hold) ||
      old.peakFreqHz != peakFreqHz ||
      old.minHz != minHz ||
      old.maxHz != maxHz ||
      old.showAxes != showAxes;
}
