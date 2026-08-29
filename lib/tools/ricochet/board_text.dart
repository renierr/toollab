import 'package:flutter/material.dart';

/// Lays out short board labels — HP numbers, score popups, chip captions — and
/// caches the result.
///
/// A busy board lays out sixty-odd numbers per frame, and `TextPainter.layout`
/// is far too expensive to run that often. The distinct strings on screen are
/// few and highly repetitive ("12", "+240", "PIERCE"), so caching by the exact
/// draw parameters turns almost every frame into pure paint calls.
class BoardText {
  BoardText._();

  static final Map<String, TextPainter> _cache = {};

  /// Beyond this the cache is dropped wholesale rather than evicted one by one:
  /// entries only accumulate when the board's numbers churn, and rebuilding a
  /// few dozen painters once is cheaper than tracking usage every draw.
  static const int _maxEntries = 512;

  static TextPainter _painter(
    String text,
    double size,
    Color color,
    FontWeight weight,
    double strokeWidth,
    Color strokeColor,
  ) {
    final key =
        '$text|$size|${color.toARGB32()}|${weight.value}|'
        '$strokeWidth|${strokeColor.toARGB32()}';
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.length >= _maxEntries) _cache.clear();

    final style = TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: 1,
      color: strokeWidth > 0 ? null : color,
      foreground: strokeWidth > 0
          ? (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor)
          : null,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    _cache[key] = painter;
    return painter;
  }

  /// Draws [text] centered on ([x], [y]). Pass [strokeWidth] to first lay down
  /// an outline in [strokeColor], which is what keeps a white HP number legible
  /// on a bright tile.
  static void draw(
    Canvas canvas,
    String text, {
    required double x,
    required double y,
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w800,
    double strokeWidth = 0,
    Color strokeColor = const Color(0xD9082F49),
  }) {
    if (strokeWidth > 0) {
      final outline = _painter(
        text,
        size,
        color,
        weight,
        strokeWidth,
        strokeColor,
      );
      outline.paint(
        canvas,
        Offset(x - outline.width / 2, y - outline.height / 2),
      );
    }
    final fill = _painter(text, size, color, weight, 0, strokeColor);
    fill.paint(canvas, Offset(x - fill.width / 2, y - fill.height / 2));
  }

  /// Width of [text] as it would be drawn, for sizing a chip around it.
  static double measure(
    String text, {
    required double size,
    FontWeight weight = FontWeight.w800,
  }) => _painter(
    text,
    size,
    const Color(0xFFFFFFFF),
    weight,
    0,
    const Color(0xFF000000),
  ).width;
}
