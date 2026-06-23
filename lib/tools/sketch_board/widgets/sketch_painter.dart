import 'package:flutter/material.dart';

import '../geometry/element_bounds.dart';
import '../geometry/element_renderer.dart';
import '../sketch_board_state.dart';

/// Renders the scene: committed elements, the live draft, the selection overlay
/// (per-element outlines, union box, resize + rotation handles) and the marquee.
class SketchPainter extends CustomPainter {
  final SketchBoardState state;
  final Color handleColor;

  SketchPainter({required this.state, required this.handleColor})
    : super(repaint: state);

  @override
  void paint(Canvas canvas, Size size) {
    state.setViewSize(size);

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
    _paintMarquee(canvas);
  }

  void _paintSelection(Canvas canvas) {
    final selected = state.selectedElements;
    if (selected.isEmpty) return;

    final outline = Paint()
      ..color = handleColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final el in selected) {
      final b = elementBounds(el);
      canvas.drawRect(
        Rect.fromPoints(
          state.worldToScreen(b.topLeft),
          state.worldToScreen(b.bottomRight),
        ),
        outline,
      );
    }

    final union = state.selectionBounds;
    if (union == null || (union.width <= 0 && union.height <= 0)) return;
    final screenRect = Rect.fromPoints(
      state.worldToScreen(union.topLeft),
      state.worldToScreen(union.bottomRight),
    ).inflate(2);

    canvas.drawRect(
      screenRect,
      Paint()
        ..color = handleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Rotation handle (stem + knob above the top edge).
    final top = screenRect.topCenter;
    final knob = top - const Offset(0, SketchBoardState.rotationHandleGap);
    canvas.drawLine(
      top,
      knob,
      Paint()
        ..color = handleColor
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(knob, 6, Paint()..color = Colors.white);
    canvas.drawCircle(
      knob,
      6,
      Paint()
        ..color = handleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final fill = Paint()..color = Colors.white;
    final stroke = Paint()
      ..color = handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final p in handlePositions(union).values) {
      final r = Rect.fromCenter(
        center: state.worldToScreen(p),
        width: 9,
        height: 9,
      );
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
    }
  }

  void _paintMarquee(Canvas canvas) {
    final box = state.marqueeRectWorld;
    final lasso = state.lassoWorld;
    final fill = Paint()..color = handleColor.withValues(alpha: 0.1);
    final stroke = Paint()
      ..color = handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    if (box != null) {
      final r = Rect.fromPoints(
        state.worldToScreen(box.topLeft),
        state.worldToScreen(box.bottomRight),
      );
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
    } else if (lasso.length > 1) {
      final path = Path()
        ..moveTo(
          state.worldToScreen(lasso.first).dx,
          state.worldToScreen(lasso.first).dy,
        );
      for (final p in lasso.skip(1)) {
        final sp = state.worldToScreen(p);
        path.lineTo(sp.dx, sp.dy);
      }
      canvas.drawPath(path, fill..style = PaintingStyle.fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) =>
      oldDelegate.handleColor != handleColor;
}
