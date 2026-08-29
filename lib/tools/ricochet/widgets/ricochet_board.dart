import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/geometry.dart';
import '../engine/ricochet_engine.dart';
import 'ricochet_board_painter.dart';

/// The playfield: the painted board plus the drag-to-aim input.
///
/// The board keeps its fixed 480×760 proportions at any size, so a phone and a
/// maximized desktop window play an identical game and only the scale differs.
/// Pointer positions are mapped back through that same fit, which is why aiming
/// lands where the player expects at every scale.
class RicochetBoard extends StatelessWidget {
  final RicochetEngine engine;

  const RicochetBoard({super.key, required this.engine});

  static Offset _toBoardSpace(Offset local, Size size) {
    final scale = math.min(
      size.width / Board.width,
      size.height / Board.height,
    );
    if (scale <= 0) return Offset.zero;
    return Offset(
      (local.dx - (size.width - Board.width * scale) / 2) / scale,
      (local.dy - (size.height - Board.height * scale) / 2) / scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: Board.width / Board.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          // Raw pointer events rather than a pan gesture: aiming must begin on
          // touch-down, before any movement, so the preview appears instantly.
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                engine.beginAim(_toBoardSpace(event.localPosition, size)),
            onPointerMove: (event) =>
                engine.updateAim(_toBoardSpace(event.localPosition, size)),
            onPointerUp: (event) =>
                engine.releaseAim(_toBoardSpace(event.localPosition, size)),
            onPointerCancel: (_) => engine.cancelAim(),
            child: CustomPaint(
              painter: RicochetBoardPainter(engine),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}
