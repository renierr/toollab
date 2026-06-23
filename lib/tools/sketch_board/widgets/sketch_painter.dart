import 'package:flutter/material.dart';

import '../geometry/element_bounds.dart';
import '../geometry/element_renderer.dart';
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
