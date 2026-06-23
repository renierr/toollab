import 'package:flutter/material.dart';

import '../geometry/element_bounds.dart';
import '../geometry/element_renderer.dart';
import '../models/sketch_enums.dart';
import '../sketch_board_state.dart';

/// Renders the whole scene: background, committed elements, the live draft, and
/// the selection overlay. Bound to [state] as its repaint listenable.
class SketchPainter extends CustomPainter {
  final SketchBoardState state;
  final Color handleColor;

  SketchPainter({required this.state, required this.handleColor})
    : super(repaint: state);

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);

    canvas.save();
    canvas.translate(state.offset.dx, state.offset.dy);
    canvas.scale(state.scale);

    for (final el in state.elements) {
      drawElement(canvas, el, imageResolver: state.imageFor);
    }
    final draft = state.draft;
    if (draft != null) {
      drawElement(canvas, draft, imageResolver: state.imageFor, preview: true);
    }
    canvas.restore();

    _paintSelection(canvas);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (state.background) {
      case CanvasBackground.white:
        canvas.drawRect(rect, Paint()..color = Colors.white);
      case CanvasBackground.black:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF111111));
      case CanvasBackground.checkerboard:
        canvas.drawRect(rect, Paint()..color = const Color(0xFFF5F5F7));
        const tile = 16.0;
        final light = Paint()..color = const Color(0xFFE9E9EE);
        for (double y = 0; y < size.height; y += tile) {
          for (double x = 0; x < size.width; x += tile) {
            final even = (((x ~/ tile) + (y ~/ tile)) % 2) == 0;
            if (even) canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), light);
          }
        }
    }
  }

  void _paintSelection(Canvas canvas) {
    final sel = state.selectedElement;
    if (sel == null) return;
    final b = elementBounds(sel);
    if (b.width <= 0 && b.height <= 0) return;

    final tl = state.worldToScreen(b.topLeft);
    final br = state.worldToScreen(b.bottomRight);
    final screenRect = Rect.fromPoints(tl, br);

    final border = Paint()
      ..color = handleColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(screenRect.inflate(2), border);

    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final p in handlePositions(b).values) {
      final sp = state.worldToScreen(p);
      final r = Rect.fromCenter(center: sp, width: 9, height: 9);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) =>
      oldDelegate.handleColor != handleColor;
}
