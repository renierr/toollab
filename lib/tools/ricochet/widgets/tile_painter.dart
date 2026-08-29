import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/tile.dart';
import '../ricochet_colors.dart';
import '../board_text.dart';

/// Draws Ricochet's tiles and pickups.
///
/// Deliberately free of engine and widget state: it takes a [Brick] and a rect
/// and nothing else. That is what lets the in-game tile legend render the very
/// same art the board does, from a literal brick — the reference page can never
/// drift from what a player actually sees.
class TilePainter {
  TilePainter._();

  static const Color _tileOutline = Color(0x47000000);
  static const Color _rampOutline = Color(0x99082F49);
  static const Color _orbOutline = Color(0x8C0F172A);
  static const Color _numberOutline = Color(0xD9082F49);

  /// Paints one tile filling [rect]. [brick] only needs a type, an HP value and
  /// a flash level, so callers may hand in a throwaway instance.
  static void paintTile(Canvas canvas, Brick brick, Rect rect) {
    switch (brick.type) {
      case TileType.rampA:
      case TileType.rampB:
        _paintRamp(canvas, brick, rect);
      case TileType.bomb:
        _paintBomb(canvas, brick, rect);
      case TileType.orb:
        _paintOrb(canvas, brick, rect);
      case TileType.normal:
      case TileType.gift:
      case TileType.mult:
      case TileType.pierce:
      case TileType.blast:
      case TileType.split:
        _paintPlate(canvas, brick, rect);
    }
  }

  /// A solid right triangle filling half the cell — the other half is air the
  /// ball passes straight through, so nothing is drawn there.
  static void _paintRamp(Canvas canvas, Brick brick, Rect rect) {
    final path = _rampPath(brick.type.isRampA, rect);
    canvas.drawPath(path, Paint()..color = RicochetColors.forTile(brick));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _rampOutline,
    );

    // The number sits on the triangle's centroid so it stays inside the solid
    // half whichever way the slope leans.
    BoardText.draw(
      canvas,
      '${brick.hp}',
      x: rect.left + rect.width * (brick.type.isRampA ? 0.63 : 0.37),
      y: rect.top + rect.height * 0.68,
      size: 13,
      color: Colors.white,
      strokeWidth: 3,
      strokeColor: _numberOutline,
    );

    if (brick.flash > 0) {
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: brick.flash * 0.7),
      );
    }
  }

  static Path _rampPath(bool isRampA, Rect rect) {
    final path = Path()..moveTo(rect.left, rect.bottom);
    path.lineTo(rect.right, rect.bottom);
    // rampA ('/') is solid in the lower right, rampB ('\') in the lower left.
    path.lineTo(isRampA ? rect.right : rect.left, rect.top);
    path.close();
    return path;
  }

  /// The bomb is the whole tile — there is no plate behind it. Without one it
  /// has to carry its own contrast against the near-black board, hence the lit
  /// rim and the highlight rather than a flat dark casing.
  static void _paintBomb(Canvas canvas, Brick brick, Rect rect) {
    final center = Offset(rect.center.dx, rect.center.dy + 2);
    final radius = rect.width * 0.36;

    canvas.drawCircle(center, radius, Paint()..color = RicochetColors.bombBody);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = RicochetColors.bombRim,
    );
    canvas.drawCircle(
      center.translate(-radius * 0.3, -radius * 0.34),
      radius * 0.42,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    final mx = rect.center.dx;
    final my = rect.center.dy;
    final fuse = Path()
      ..moveTo(mx + radius * 0.6, center.dy - radius * 0.8)
      ..quadraticBezierTo(mx + 11, my - 15, mx + 15, my - 12);
    canvas.drawPath(
      fuse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = RicochetColors.mult,
    );
    canvas.drawCircle(
      Offset(mx + 16, my - 12),
      3,
      Paint()..color = RicochetColors.fuse,
    );

    if (brick.flash > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.white.withValues(alpha: brick.flash * 0.8),
      );
    }
  }

  /// A round bumper. Being round, the corners of its cell are empty air.
  static void _paintOrb(Canvas canvas, Brick brick, Rect rect) {
    final center = rect.center;
    final radius = rect.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = RicochetColors.forTile(brick),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _orbOutline,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      math.pi * 0.95,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    BoardText.draw(
      canvas,
      '${brick.hp}',
      x: center.dx,
      y: center.dy + 1,
      size: 12,
      color: Colors.white,
    );

    if (brick.flash > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.white.withValues(alpha: brick.flash * 0.7),
      );
    }
  }

  /// The ordinary rounded plate every non-shaped tile sits on, plus whichever
  /// glyph its kind adds on top.
  static void _paintPlate(Canvas canvas, Brick brick, Rect rect) {
    final plate = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    canvas.drawRRect(plate, Paint()..color = RicochetColors.forTile(brick));
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _tileOutline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 3,
          rect.top + 3,
          rect.width - 6,
          rect.height * 0.32,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    final mx = rect.center.dx;
    final my = rect.center.dy;
    switch (brick.type) {
      case TileType.gift:
        BoardText.draw(
          canvas,
          '?',
          x: mx,
          y: my - 4,
          size: 19,
          color: Colors.white,
        );
        _paintSmallHp(canvas, brick, mx, my + 11);
      case TileType.mult:
        BoardText.draw(
          canvas,
          '×2',
          x: mx,
          y: my - 4,
          size: 14,
          color: Colors.white,
          weight: FontWeight.w900,
        );
        _paintSmallHp(canvas, brick, mx, my + 10);
      case TileType.pierce:
        _paintChevrons(canvas, mx, my);
        _paintSmallHp(canvas, brick, mx, my + 11);
      case TileType.blast:
        _paintStarburst(canvas, mx, my - 4);
        _paintSmallHp(canvas, brick, mx, my + 11);
      case TileType.split:
        _paintSplit(canvas, mx, my - 4);
        _paintSmallHp(canvas, brick, mx, my + 11);
      case TileType.normal:
      case TileType.bomb:
      case TileType.orb:
      case TileType.rampA:
      case TileType.rampB:
        BoardText.draw(
          canvas,
          '${brick.hp}',
          x: mx,
          y: my + 1,
          size: brick.hp > 99 ? 12 : (brick.hp > 9 ? 15 : 17),
          color: Colors.white,
        );
    }

    if (brick.flash > 0) {
      canvas.drawRRect(
        plate,
        Paint()..color = Colors.white.withValues(alpha: brick.flash * 0.8),
      );
    }
  }

  static void _paintSplit(Canvas canvas, double mx, double my) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawLine(Offset(mx, my + 7), Offset(mx, my - 7), paint);
    canvas.drawLine(Offset(mx, my - 7), Offset(mx - 7, my - 1), paint);
    canvas.drawLine(Offset(mx, my - 7), Offset(mx + 7, my - 1), paint);
  }

  static void _paintSmallHp(Canvas canvas, Brick brick, double x, double y) {
    BoardText.draw(
      canvas,
      '${brick.hp}',
      x: x,
      y: y,
      size: 11,
      color: Colors.white,
      weight: FontWeight.w700,
    );
  }

  /// The pierce tile's double chevron.
  static void _paintChevrons(Canvas canvas, double mx, double my) {
    final paint = Paint()..color = Colors.white;
    for (final dx in const [-9.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(mx + dx, my - 10)
          ..lineTo(mx + dx + 7, my - 3)
          ..lineTo(mx + dx, my + 4)
          ..close(),
        paint,
      );
    }
  }

  /// The blast tile's eight-point starburst.
  static void _paintStarburst(Canvas canvas, double mx, double my) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = (math.pi / 4) * i - math.pi / 2;
      final radius = i.isEven ? 8.0 : 3.4;
      final px = mx + math.cos(angle) * radius;
      final py = my + math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  /// The green (+) ball pickup. [phase] drives the idle pulse; pass 0 for a
  /// still frame in the legend.
  static void paintPickup(
    Canvas canvas,
    Offset center,
    double radius,
    double phase,
  ) {
    final pulse = 1 + math.sin(phase) * 0.12;
    canvas.drawCircle(
      center,
      radius * pulse + 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = RicochetColors.pickup.withValues(alpha: 0.35 * pulse),
    );
    canvas.drawCircle(
      center,
      radius * pulse,
      Paint()..color = RicochetColors.pickup,
    );
    final cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = Colors.white;
    canvas.drawLine(center.translate(-7, 0), center.translate(7, 0), cross);
    canvas.drawLine(center.translate(0, -7), center.translate(0, 7), cross);
  }
}
