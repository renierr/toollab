import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/geometry.dart';
import '../engine/ricochet_engine.dart';
import '../ricochet_colors.dart';
import '../board_text.dart';
import 'tile_painter.dart';

/// Draws the whole board in logical board units — the canvas is scaled to fit
/// before this runs, so every coordinate here matches the simulation's.
class RicochetBoardPainter extends CustomPainter {
  final RicochetEngine engine;

  RicochetBoardPainter(this.engine) : super(repaint: engine.frames);

  static const Rect _bounds = Rect.fromLTWH(0, 0, Board.width, Board.height);

  final math.Random _shakeRandom = math.Random();
  final Paint _ballPaint = Paint();
  final Paint _particlePaint = Paint();
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(
      size.width / Board.width,
      size.height / Board.height,
    );
    canvas.translate(
      (size.width - Board.width * scale) / 2,
      (size.height - Board.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.clipRect(_bounds);

    canvas.drawRect(_bounds, Paint()..color = RicochetColors.board);
    if (engine.shake > 0) {
      canvas.translate(
        (_shakeRandom.nextDouble() - 0.5) * engine.shake,
        (_shakeRandom.nextDouble() - 0.5) * engine.shake,
      );
    }

    _paintDangerZone(canvas);
    _paintPickups(canvas);
    _paintBricks(canvas);
    _paintBalls(canvas);
    _paintLauncher(canvas);
    _paintChargeChips(canvas);
    _paintAimPreview(canvas);
    _paintRings(canvas);
    _paintParticles(canvas);
    _paintTexts(canvas);
    _paintHint(canvas);
    _paintBanner(canvas);
    // Last, so a ball or a particle never paints over the wall it just hit.
    _paintWalls(canvas);

    canvas.restore();
  }

  /// The three walls a ball bounces off, plus the open floor it returns
  /// through. Drawn as an explicit rim because the board is the same near-black
  /// as the page around it — without this the player cannot see where a shot
  /// will come back from.
  void _paintWalls(Canvas canvas) {
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = RicochetColors.wall;
    // Inset by half the stroke so the whole line stays inside the clip.
    final outer = _bounds.deflate(1);
    canvas.drawLine(outer.topLeft, outer.topRight, rim);
    canvas.drawLine(outer.topLeft, outer.bottomLeft, rim);
    canvas.drawLine(outer.topRight, outer.bottomRight, rim);

    // A faint second line inside the rim reads as a surface with depth rather
    // than a border drawn around a picture.
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = RicochetColors.wall.withValues(alpha: 0.3);
    final gap = _bounds.deflate(4.5);
    canvas.drawLine(gap.topLeft, gap.topRight, inner);
    canvas.drawLine(gap.topLeft, gap.bottomLeft, inner);
    canvas.drawLine(gap.topRight, gap.bottomRight, inner);
  }

  void _paintDangerZone(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTRB(0, Board.dangerY, Board.width, Board.height),
      Paint()..color = RicochetColors.danger.withValues(alpha: 0.07),
    );
    // The line is dashed by hand: Flutter has no dash support on Paint, and one
    // straight run of segments is cheaper than building a PathMetric each frame.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = RicochetColors.danger.withValues(alpha: 0.55);
    for (var x = 0.0; x < Board.width; x += 18) {
      canvas.drawLine(
        Offset(x, Board.dangerY),
        Offset(math.min(x + 10, Board.width), Board.dangerY),
        paint,
      );
    }
  }

  void _paintPickups(Canvas canvas) {
    final offset = engine.rowShiftOffset;
    for (final pickup in engine.pickups) {
      TilePainter.paintPickup(
        canvas,
        Offset(pickup.x, pickup.y + offset),
        pickup.radius,
        engine.timeSeconds * 5 + pickup.seed,
      );
    }
  }

  void _paintBricks(Canvas canvas) {
    final offset = engine.rowShiftOffset;
    for (final brick in engine.bricks) {
      TilePainter.paintTile(
        canvas,
        brick,
        Rect.fromLTWH(brick.x, brick.y + offset, brick.width, brick.height),
      );
    }
  }

  void _paintBalls(Canvas canvas) {
    for (final ball in engine.balls) {
      final trailColor = ball.pierce
          ? RicochetColors.pierceLight
          : RicochetColors.ballTrail;
      for (var t = 0; t < ball.trailLength; t++) {
        final fade = t / ball.trailLength;
        canvas.drawCircle(
          ball.trailAt(t),
          Board.ballRadius * fade * 0.8,
          _ballPaint..color = trailColor.withValues(alpha: fade * 0.28),
        );
      }
      final color = ball.pierce
          ? RicochetColors.pierceLight
          : (ball.bomb ? RicochetColors.blastLight : RicochetColors.ball);
      canvas.drawCircle(
        Offset(ball.x, ball.y),
        Board.ballRadius,
        _ballPaint..color = color,
      );
    }
  }

  void _paintLauncher(Canvas canvas) {
    final center = Offset(engine.originX, Board.launchY);
    canvas.drawCircle(center, 13, Paint()..color = RicochetColors.launcher);
    canvas.drawCircle(
      center,
      19,
      Paint()..color = RicochetColors.launcher.withValues(alpha: 0.25),
    );
    BoardText.draw(
      canvas,
      '${engine.totalBalls}',
      x: center.dx,
      y: center.dy + 1,
      size: 11,
      color: Colors.white,
    );
  }

  /// Banked pierce and bomb charges, pinned just above the launcher's row at a
  /// fixed spot — they stay put wherever the launcher slides to.
  void _paintChargeChips(Canvas canvas) {
    final pierce = engine.pendingPierce;
    if (pierce > 0) {
      _paintChip(
        canvas,
        engine.strings.chargeChip(engine.strings.pierceLabel, pierce),
        Board.width / 2 - RicochetTuning.chipOffsetX,
        RicochetColors.pierceLight,
      );
    }
    final bomb = engine.pendingBomb;
    if (bomb > 0) {
      _paintChip(
        canvas,
        engine.strings.chargeChip(engine.strings.bombLabel, bomb),
        Board.width / 2 + RicochetTuning.chipOffsetX,
        RicochetColors.blastLight,
      );
    }
  }

  void _paintChip(Canvas canvas, String label, double centerX, Color color) {
    const fontSize = 10.0;
    final width = BoardText.measure(label, size: fontSize) + 14;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerX - width / 2, RicochetTuning.chipY, width, 17),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = RicochetColors.board.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
    BoardText.draw(
      canvas,
      label,
      x: centerX,
      y: RicochetTuning.chipY + 9,
      size: fontSize,
      color: color,
    );
  }

  void _paintAimPreview(Canvas canvas) {
    final point = engine.aimPoint;
    if (!engine.aiming || point == null || engine.mode != GameMode.aiming) {
      return;
    }
    final points = engine.previewTrajectory(engine.aimDirection(point));
    if (points.length < 2) return;

    // Dotted, by walking the polyline and stamping a dot every 14 units — the
    // browser original's `setLineDash([3, 11])`.
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    var carry = 0.0;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      final segment = (to - from).distance;
      if (segment <= 0) continue;
      final step = (to - from) / segment;
      var travelled = carry;
      while (travelled < segment) {
        canvas.drawCircle(from + step * travelled, 1.4, paint);
        travelled += 14;
      }
      carry = travelled - segment;
    }
    canvas.drawCircle(points.last, 4, Paint()..color = Colors.white);
  }

  void _paintRings(Canvas canvas) {
    for (final ring in engine.rings) {
      canvas.drawCircle(
        Offset(ring.x, ring.y),
        ring.radius,
        _ringPaint
          ..color = RicochetColors.blastLight.withValues(
            alpha: (ring.life * 0.7).clamp(0.0, 1.0),
          ),
      );
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in engine.particles) {
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        _particlePaint
          ..color = particle.color.withValues(alpha: particle.alpha),
      );
    }
  }

  void _paintTexts(Canvas canvas) {
    for (final text in engine.texts) {
      BoardText.draw(
        canvas,
        text.text,
        x: text.x,
        y: text.y,
        size: text.size,
        color: text.color.withValues(alpha: text.alpha),
      );
    }
  }

  void _paintHint(Canvas canvas) {
    if (engine.hintAlpha <= 0) return;
    BoardText.draw(
      canvas,
      engine.strings.dragToAim,
      x: Board.width / 2,
      y: Board.launchY - 96,
      size: 14,
      color: Colors.white.withValues(alpha: engine.hintAlpha * 0.75),
      weight: FontWeight.w600,
    );
  }

  void _paintBanner(Canvas canvas) {
    final level = engine.bannerLevel;
    if (level == null || engine.bannerTimer <= 0) return;
    // Snaps to full opacity and fades over the last third, so the level number
    // is readable the instant the board appears.
    final alpha = (engine.bannerTimer / 0.5).clamp(0.0, 1.0);
    BoardText.draw(
      canvas,
      engine.strings.levelBanner(level),
      x: Board.width / 2,
      y: Board.height * 0.32,
      size: 34,
      color: Colors.white.withValues(alpha: alpha),
      weight: FontWeight.w900,
      strokeWidth: 6,
      strokeColor: RicochetColors.board.withValues(alpha: alpha * 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant RicochetBoardPainter oldDelegate) =>
      oldDelegate.engine != engine;
}
