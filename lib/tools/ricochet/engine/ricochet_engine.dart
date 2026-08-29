import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import 'package:flutter/foundation.dart';

import '../frame_beacon.dart';
import '../ricochet_audio_service.dart';
import '../ricochet_colors.dart';
import 'ball.dart';
import 'effects.dart';
import 'geometry.dart';
import 'level_generator.dart';
import 'ricochet_audio.dart';
import '../ricochet_store.dart';
import 'ricochet_strings.dart';
import 'tile.dart';

/// What the board is doing right now. Input, the HUD and the action buttons all
/// branch on this rather than on a pile of independent flags.
enum GameMode {
  /// Waiting for the player to drag out a shot.
  aiming,

  /// A volley is in flight.
  shooting,

  /// The board is animating one row downward between turns.
  shifting,

  /// Level cleared; the celebration is playing before the next board.
  between,

  /// A brick crossed the danger line.
  over,
}

/// The four unlimited-use power-ups, from the menu and from gift tiles.
enum PowerUp { balls, pierce, bomb, clearRow }

/// Tuning constants. Everything here is in board units and seconds.
class RicochetTuning {
  RicochetTuning._();

  static const double ballSpeed = 560;
  static const double staggerSeconds = 0.07;

  /// A volley that has not resolved by now is force-ended, so a pathological
  /// trajectory can never wedge the game.
  static const double maxVolleySeconds = 25;

  /// Shots may not be fired flatter than this, or a ball could travel forever
  /// along the floor.
  static const double minAngle = math.pi / 20;

  /// Ceiling on the banked stash. Trimmed back to [volleyCap] at each clear.
  static const int maxBalls = 150;

  /// Most balls one volley fires, however large the stash.
  static const int volleyCap = 100;

  static const double shiftSeconds = 0.22;
  static const int speedBoostStep = 3;
  static const double autoSpeedAfterSeconds = 6;
  static const int maxSpeed = 10;

  /// A ball may not bounce off two ramps or orbs closer together than this,
  /// which is what stops it rattling forever inside a cluster of them.
  static const double shapeCooldown = 0.09;

  static const double bombChargeDamage = 50;
  static const double explosionRadius = Board.cell * 1.95;

  static const double chipY = Board.launchY - 40;
  static const double chipOffsetX = 62;
  static const double toastY = Board.launchY - 64;
}

/// The whole Ricochet simulation: board state, physics, scoring and saves.
///
/// Deliberately free of Flutter widgets — it owns no `BuildContext` and builds
/// no UI. The page drives it with [update] once per frame and paints from its
/// public state; localized text arrives through [strings].
class RicochetEngine {
  final RicochetStore _store;
  final math.Random _random;
  late final LevelGenerator _generator;

  final FrameBeacon _frames = FrameBeacon();
  final FrameBeacon _hud = FrameBeacon();

  /// Repaint signal for the board painter — fires every simulated frame.
  Listenable get frames => _frames;

  /// Rebuild signal for the HUD and action buttons — fires only when score,
  /// level, ball count, charges or mode change.
  Listenable get hud => _hud;

  RicochetEngine({RicochetStore? store, math.Random? random})
    : _store = store ?? const RicochetStore(),
      _random = random ?? math.Random() {
    _generator = LevelGenerator(() => _uidSeq++, random: _random);
  }

  RicochetStrings strings = RicochetStrings.fallback();

  final List<Brick> bricks = [];
  final List<Pickup> pickups = [];
  final List<Ball> balls = [];
  final List<Particle> particles = [];
  final List<FloatingText> texts = [];
  final List<Ring> rings = [];

  int _uidSeq = 1;

  GameMode mode = GameMode.between;
  int level = 1;
  int score = 0;
  int best = 0;
  int totalBalls = 1;
  double originX = Board.width / 2;

  int pierceCharges = 0;
  int bombCharges = 0;
  int _pierceLeft = 0;
  int _bombLeft = 0;

  /// Charges the chips should show: banked plus not-yet-fired.
  int get pendingPierce => pierceCharges + _pierceLeft;
  int get pendingBomb => bombCharges + _bombLeft;

  int _pendingShots = 0;
  Offset _volleyDirection = const Offset(0, -1);
  double _volleyAccumulator = 0;
  double _volleyElapsed = 0;
  double? _firstLandX;

  /// 0..1 progress of the between-turns row drop, used by the painter to slide
  /// the bricks smoothly instead of teleporting them.
  double shiftProgress = 0;
  double _betweenTimer = 0;

  double timeSeconds = 0;
  double shake = 0;
  double hintAlpha = 1;
  bool _firedOnce = false;

  bool aiming = false;
  Offset? aimPoint;

  /// The keyboard's aim, in radians, `-pi/2` being straight up. Kept in sync
  /// from the pointer too, so picking up the keyboard mid-run continues from
  /// wherever the last drag left the sight rather than snapping to vertical.
  double _aimAngle = -math.pi / 2;

  int speedMultiplier = 1;
  bool _autoSped = false;

  int? bannerLevel;
  double bannerTimer = 0;

  /// True while [_collideBricks] is walking [bricks]. An explosion triggered
  /// mid-scan must not compact the list out from under that walk.
  bool _scanning = false;

  /// Cell-bucketed bricks, so a ball tests the handful of tiles it could
  /// possibly touch instead of the whole board. A boosted volley of a hundred
  /// balls sub-steps several times per frame; at that rate a linear scan of
  /// sixty bricks is millions of comparisons a second, and this is the one hot
  /// loop in the game. Bricks are grid-aligned by construction, so the buckets
  /// are exact rather than an approximation.
  final Map<int, List<Brick>> _grid = {};
  bool _gridDirty = true;
  int _gridCount = -1;

  bool _saveDirty = false;
  double _saveTimer = 0;
  Map<String, dynamic>? _checkpoint;
  bool _disposed = false;

  /// Whether the action buttons should be live — they only do anything while a
  /// volley is actually in flight.
  bool get volleyActive => mode == GameMode.shooting;

  /// Whether a turn is resolving itself with no input needed. The page keeps
  /// the screen awake and keeps simulating in the background while this holds.
  bool get turnInProgress =>
      mode == GameMode.shooting ||
      mode == GameMode.shifting ||
      mode == GameMode.between;

  /// Whether time-based game state still needs another frame. Pointer events
  /// repaint a stationary aim preview without keeping the ticker alive.
  bool get needsFrame =>
      turnInProgress ||
      shake > 0 ||
      bannerTimer > 0 ||
      (_firedOnce && hintAlpha > 0) ||
      particles.isNotEmpty ||
      texts.isNotEmpty ||
      rings.isNotEmpty;

  bool get hasPickups => mode != GameMode.over && pickups.isNotEmpty;

  // ---------------------------------------------------------------- lifecycle

  /// Restores a saved run, or starts a fresh one when there is nothing to
  /// restore. Also loads the persisted best score either way.
  Future<void> start() async {
    best = await _store.loadBest();
    final saved = await _store.loadSave();
    if (_disposed) return;
    if (saved != null && _hydrate(saved)) {
      if (bricks.isEmpty) _generateLevel(level);
      _showBanner(level);
    } else {
      _generateLevel(1);
      _showBanner(1);
    }
    mode = GameMode.aiming;
    _markHudDirty();
  }

  void dispose() {
    _disposed = true;
    if (mode != GameMode.over) unawaited(_saveNow());
    _frames.dispose();
    _hud.dispose();
  }

  // -------------------------------------------------------------- frame drive

  /// Advances the simulation by [dt] seconds. The caller clamps [dt]; a frame
  /// longer than a fifth of a second is a stall, not slow motion.
  void update(double dt) {
    if (mode == GameMode.over) {
      _frames.ping();
      return;
    }

    timeSeconds += dt;
    if (shake > 0) shake = math.max(0, shake - dt * 26);
    if (_firedOnce && hintAlpha > 0) {
      hintAlpha = math.max(0, hintAlpha - dt * 2);
    }
    if (bannerTimer > 0) bannerTimer = math.max(0, bannerTimer - dt);

    _stepEffects(dt);

    switch (mode) {
      case GameMode.shooting:
        _stepVolley(dt);
      case GameMode.shifting:
        shiftProgress += dt / RicochetTuning.shiftSeconds;
        if (shiftProgress >= 1) _finalizeShift();
      case GameMode.between:
        _betweenTimer -= dt;
        if (_betweenTimer <= 0) {
          level++;
          _generateLevel(level);
          _markHudDirty();
          mode = GameMode.aiming;
        }
      case GameMode.aiming:
      case GameMode.over:
        break;
    }

    _sweepDead();
    _saveTimer += dt;
    if (_saveDirty && _saveTimer > 0.5) {
      _saveTimer = 0;
      unawaited(_saveNow());
    }
    _frames.ping();
  }

  void _stepVolley(double dt) {
    _volleyElapsed += dt;
    // A long volley is usually the player watching one slow ball; speed it up
    // rather than making them press the button.
    if (!_autoSped &&
        speedMultiplier == 1 &&
        _volleyElapsed > RicochetTuning.autoSpeedAfterSeconds) {
      speedMultiplier = RicochetTuning.speedBoostStep;
      _autoSped = true;
      _addText(
        Board.width / 2,
        Board.height - 150,
        strings.autoSpeed(speedMultiplier),
        RicochetColors.bonus,
        1,
        17,
      );
      _markHudDirty();
    }

    final stagger = speedMultiplier > 1
        ? RicochetTuning.staggerSeconds / 3
        : RicochetTuning.staggerSeconds;
    _volleyAccumulator += dt;
    while (_pendingShots > 0 && _volleyAccumulator >= stagger) {
      _volleyAccumulator -= stagger;
      _pendingShots--;
      final withPierce = _pierceLeft > 0;
      final withBomb = _bombLeft > 0;
      if (withPierce) _pierceLeft--;
      if (withBomb) _bombLeft--;
      balls.add(
        Ball(
          x: originX,
          y: Board.launchY - Board.ballRadius,
          vx: _volleyDirection.dx * RicochetTuning.ballSpeed,
          vy: _volleyDirection.dy * RicochetTuning.ballSpeed,
          pierce: withPierce,
          bomb: withBomb,
        ),
      );
      if (withPierce || withBomb) _markHudDirty();
    }

    _moveBalls(dt);

    if (_pendingShots == 0 && balls.isEmpty) {
      // The launcher slides to wherever the first ball came home, so a good
      // angle sets up the next shot for you.
      originX = (_firstLandX ?? originX).clamp(
        Board.ballRadius + 4,
        Board.width - Board.ballRadius - 4,
      );
      _startShift();
    }
  }

  // ------------------------------------------------------------------ physics

  void _moveBalls(double dt) {
    final k = speedMultiplier.toDouble();
    // Sub-step so no ball can move further than its own radius in one step —
    // that is what keeps a boosted volley from tunnelling through a brick.
    final steps = math.max(
      1,
      (RicochetTuning.ballSpeed * k * dt / Board.ballRadius).ceil(),
    );
    final sdt = dt / steps;

    for (var i = balls.length - 1; i >= 0; i--) {
      final ball = balls[i];
      var returned = false;
      for (var s = 0; s < steps; s++) {
        ball.x += ball.vx * sdt * k;
        ball.y += ball.vy * sdt * k;

        if (ball.x < Board.ballRadius) {
          ball.x = Board.ballRadius;
          ball.vx = ball.vx.abs();
        }
        if (ball.x > Board.width - Board.ballRadius) {
          ball.x = Board.width - Board.ballRadius;
          ball.vx = -ball.vx.abs();
        }
        if (ball.y < Board.ballRadius) {
          ball.y = Board.ballRadius;
          ball.vy = ball.vy.abs();
        }

        if (ball.cd > 0) ball.cd -= sdt;
        if (ball.shapeCd > 0) ball.shapeCd -= sdt;

        _collideBricks(ball);
        _collectPickups(ball);

        if (ball.y > Board.launchY + Board.ballRadius * 2) {
          _firstLandX ??= ball.x;
          balls.removeAt(i);
          returned = true;
          break;
        }
      }
      if (returned) continue;
      ball.addTrail(Offset(ball.x, ball.y));
    }

    if (_volleyElapsed > RicochetTuning.maxVolleySeconds) balls.clear();
  }

  void _collectPickups(Ball ball) {
    for (var i = pickups.length - 1; i >= 0; i--) {
      final pickup = pickups[i];
      final dx = ball.x - pickup.x;
      final dy = ball.y - pickup.y;
      final reach = pickup.radius + Board.ballRadius;
      if (dx * dx + dy * dy >= reach * reach) continue;
      pickups.removeAt(i);
      totalBalls = math.min(RicochetTuning.maxBalls, totalBalls + 1);
      _addText(
        pickup.x,
        pickup.y - 10,
        strings.plusOneBall,
        RicochetColors.pickup,
        0.9,
        14,
      );
      _burst(pickup.x, pickup.y, RicochetColors.pickup, 10);
      RicochetAudioService.instance.play(RicochetSfx.plus, minGapMs: 40);
      _markHudDirty();
    }
  }

  static int _cellKey(int col, int row) => row * 64 + col;

  void _markGridDirty() => _gridDirty = true;

  Map<int, List<Brick>> get _brickGrid {
    // The length check is a backstop: any add or remove invalidates the buckets
    // even if the caller forgot to say so.
    if (_gridDirty || _gridCount != bricks.length) {
      _grid.clear();
      for (final brick in bricks) {
        final key = _cellKey(
          (brick.x / Board.cell).round(),
          (brick.y / Board.cell).round(),
        );
        (_grid[key] ??= <Brick>[]).add(brick);
      }
      _gridCount = bricks.length;
      _gridDirty = false;
    }
    return _grid;
  }

  /// Every brick whose expanded cell could contain the point [x], [y].
  /// Yields at most nine buckets, and normally one or two.
  Iterable<Brick> _bricksNear(double x, double y) sync* {
    final grid = _brickGrid;
    if (grid.isEmpty) return;
    const r = Board.ballRadius;
    final colLo = ((x - r) / Board.cell).floor() - 1;
    final colHi = ((x + r) / Board.cell).floor();
    final rowLo = ((y - r) / Board.cell).floor() - 1;
    final rowHi = ((y + r) / Board.cell).floor();
    for (var row = rowLo; row <= rowHi; row++) {
      for (var col = colLo; col <= colHi; col++) {
        final bucket = grid[_cellKey(col, row)];
        if (bucket != null) yield* bucket;
      }
    }
  }

  /// Resolves [ball] against the first brick it overlaps. Returns true when a
  /// bounce happened — a piercing ball never stops, so it returns false and
  /// damages everything it is currently inside.
  bool _collideBricks(Ball ball) {
    _scanning = true;
    try {
      return _scanBricks(ball);
    } finally {
      _scanning = false;
    }
  }

  bool _scanBricks(Ball ball) {
    for (final brick in _bricksNear(ball.x, ball.y)) {
      if (brick.dead) continue;
      final left = brick.x - Board.ballRadius;
      final right = brick.x + brick.width + Board.ballRadius;
      final top = brick.y - Board.ballRadius;
      final bottom = brick.y + brick.height + Board.ballRadius;
      if (ball.x < left || ball.x > right || ball.y < top || ball.y > bottom) {
        continue;
      }

      if (brick.type.isRamp) {
        if (ball.shapeCd > 0) continue;
        if (!_hitRamp(ball, brick)) continue;
        ball.shapeCd = RicochetTuning.shapeCooldown;
        _damage(brick, 1);
        return true;
      }

      if (brick.type == TileType.orb) {
        if (ball.shapeCd > 0) continue;
        if (!_hitOrb(ball, brick)) continue;
        ball.shapeCd = RicochetTuning.shapeCooldown;
        _damage(brick, 1);
        return true;
      }

      if (ball.pierce) {
        // Drills straight on, spending one HP per brick it passes through.
        if (ball.hit.add(brick.uid)) {
          _damage(brick, 1);
          if (ball.bomb && ball.cd <= 0) {
            ball.cd = 0.06;
            explodeAt(ball.x, ball.y, RicochetTuning.bombChargeDamage);
          }
        }
        continue;
      }

      // Push out along whichever face the ball has entered least far.
      final penLeft = ball.x - left;
      final penRight = right - ball.x;
      final penTop = ball.y - top;
      final penBottom = bottom - ball.y;
      final least = math.min(
        math.min(penLeft, penRight),
        math.min(penTop, penBottom),
      );
      if (least == penLeft) {
        ball.x = left;
        ball.vx = -ball.vx.abs();
      } else if (least == penRight) {
        ball.x = right;
        ball.vx = ball.vx.abs();
      } else if (least == penTop) {
        ball.y = top;
        ball.vy = -ball.vy.abs();
      } else {
        ball.y = bottom;
        ball.vy = ball.vy.abs();
      }

      if (ball.bomb && ball.cd <= 0) {
        ball.cd = 0.06;
        explodeAt(ball.x, ball.y, RicochetTuning.bombChargeDamage);
        return true;
      }
      _damage(brick, 1);
      return true;
    }
    return false;
  }

  /// A ramp is a right triangle, not a box: two flat legs plus the 45°
  /// hypotenuse, and the other half of the cell is empty air the ball flies
  /// straight through. Treat it as the intersection of three half-planes,
  /// resolve against the one the ball has entered least far, and reflect off
  /// that face — so a leg bounces like an ordinary brick and only the slope
  /// gives the quarter turn. Returns false when the ball is in the empty half.
  bool _hitRamp(Ball ball, Brick brick) {
    final isA = brick.type.isRampA;
    final w = brick.width;
    final h = brick.height;
    final hyp = math.sqrt(w * w + h * h);

    // Outward face normal plus how far outside that face the ball's centre is.
    final faces = <(double, double, double)>[
      (0, 1, ball.y - (brick.y + h)), // flat bottom
      isA
          ? (1, 0, ball.x - (brick.x + w))
          : (-1.0, 0, brick.x - ball.x), // flat side
      isA
          ? (
              -h / hyp,
              -w / hyp,
              (w * h - (ball.x - brick.x) * h - (ball.y - brick.y) * w) / hyp,
            )
          : (
              h / hyp,
              -w / hyp,
              ((ball.x - brick.x) * h - (ball.y - brick.y) * w) / hyp,
            ),
    ];

    double bestDepth = 0;
    double bestNx = 0;
    double bestNy = 0;
    var found = false;
    for (final (nx, ny, distance) in faces) {
      final depth = Board.ballRadius - distance;
      // Clear of any one face means clear of the triangle entirely.
      if (depth <= 0) return false;
      if (!found || depth < bestDepth) {
        found = true;
        bestDepth = depth;
        bestNx = nx;
        bestNy = ny;
      }
    }

    ball.x += bestNx * bestDepth;
    ball.y += bestNy * bestDepth;
    final dot = ball.vx * bestNx + ball.vy * bestNy;
    if (dot < 0) {
      ball.vx -= 2 * dot * bestNx;
      ball.vy -= 2 * dot * bestNy;
    }
    return true;
  }

  /// An orb is round, so the corners of its cell are empty air: test the
  /// circle, not the box the broad-phase matched on. Reflecting off the curved
  /// surface is what fans outgoing angles out from the point of impact.
  bool _hitOrb(Ball ball, Brick brick) {
    final cx = brick.centerX;
    final cy = brick.centerY;
    final reach = brick.width / 2 + Board.ballRadius + 0.5;
    var nx = ball.x - cx;
    var ny = ball.y - cy;
    final distance = math.sqrt(nx * nx + ny * ny);
    if (distance > reach) return false;
    final d = distance == 0 ? 1.0 : distance;
    nx /= d;
    ny /= d;
    final dot = ball.vx * nx + ball.vy * ny;
    ball.vx -= 2 * dot * nx;
    ball.vy -= 2 * dot * ny;
    ball.x = cx + nx * reach;
    ball.y = cy + ny * reach;
    return true;
  }

  // ------------------------------------------------------------------ damage

  void _damage(Brick brick, int amount) {
    if (brick.dead) return;
    brick.hp -= amount;
    brick.flash = 1;
    // A bomb goes off on any hit, however much HP its plate claims.
    if (brick.hp <= 0 || brick.type == TileType.bomb) {
      _destroy(brick);
    } else {
      // Gap matches the clip length so two ticks never overlap: voices sum
      // in the mixer, so a stacked volley would swell in volume purely
      // with ball count. One at a time still reads as continuous.
      RicochetAudioService.instance.play(
        RicochetSfx.hit,
        minGapMs: 45,
        group: RicochetSfx.hitPrefix,
      );
    }
  }

  /// Destroyed bricks are only *marked* here and swept later by [_sweepDead].
  /// Removing one immediately would invalidate the iterator in
  /// [_collideBricks] — a piercing ball keeps scanning after a hit, and an
  /// explosion re-enters this method for every brick it chains through.
  /// Everything that reads the board already skips [Brick.dead].
  void _destroy(Brick brick) {
    if (brick.dead) return;
    brick.dead = true;

    var points = brick.maxHp * 10 + level * 2;
    if (brick.type == TileType.mult) points *= 2;
    score += points;
    _recordBest();

    if (brick.type == TileType.mult) {
      _addText(
        brick.centerX,
        brick.centerY,
        strings.scorePopupDoubled(points),
        RicochetColors.bonus,
        1,
        17,
      );
    } else {
      _addText(
        brick.centerX,
        brick.centerY,
        strings.scorePopup(points),
        RicochetColors.byHp(brick.maxHp),
        0.8,
        14,
      );
    }
    _burst(brick.centerX, brick.centerY, RicochetColors.byHp(brick.maxHp), 14);

    switch (brick.type) {
      case TileType.bomb:
        explodeAt(brick.centerX, brick.centerY);
      case TileType.gift:
        usePower(PowerUp.values[_random.nextInt(PowerUp.values.length)]);
      case TileType.pierce:
        pierceCharges++;
        _armToast(strings.pierceArmed, RicochetColors.pierceLight);
      case TileType.blast:
        bombCharges++;
        _armToast(strings.bombArmed, RicochetColors.blastLight);
      case TileType.normal:
      case TileType.mult:
      case TileType.rampA:
      case TileType.rampB:
      case TileType.orb:
        RicochetAudioService.instance.play(RicochetSfx.breakTile, minGapMs: 70);
        shake = math.min(shake + 2, 6);
    }
    _markHudDirty();
  }

  /// Drops the bricks [_destroy] marked. Safe only outside a scan of [bricks],
  /// which is why every caller is either the top of a frame or a player action.
  void _sweepDead() {
    if (_scanning) return;
    bricks.removeWhere((brick) => brick.dead);
  }

  void _armToast(String message, Color color) {
    _addText(Board.width / 2, RicochetTuning.toastY, message, color, 1.2, 15);
    RicochetAudioService.instance.play(RicochetSfx.arm);
  }

  /// Everything within ~2 cells takes [damage]. Lethal by default, which is
  /// what makes bomb tiles chain; a bomb *charge* passes a finite number.
  void explodeAt(double x, double y, [double damage = 9999]) {
    rings.add(
      Ring(x: x, y: y, radius: Board.cell * 0.5, maxRadius: Board.cell * 2.1),
    );
    _burst(x, y, RicochetColors.blastLight, 26);
    RicochetAudioService.instance.play(RicochetSfx.boom, minGapMs: 40);
    shake = math.max(shake, 10);

    final radius = RicochetTuning.explosionRadius;
    // Snapshot first: destroying a brick mutates the list, and a chained bomb
    // re-enters this method.
    final caught = bricks.where((brick) {
      if (brick.dead) return false;
      final dx = brick.centerX - x;
      final dy = brick.centerY - y;
      return dx * dx + dy * dy <= radius * radius;
    }).toList();
    for (final brick in caught) {
      _damage(brick, damage.round());
    }
    _sweepDead();
  }

  void clearLowestRow() {
    if (bricks.isEmpty) return;
    var maxY = double.negativeInfinity;
    for (final brick in bricks) {
      if (!brick.dead && brick.y > maxY) maxY = brick.y;
    }
    final row = bricks.where((b) => !b.dead && (b.y - maxY).abs() < 2).toList();
    _addText(
      Board.width / 2,
      maxY + Board.cell / 2,
      strings.rowCleared,
      RicochetColors.pickup,
      1,
      17,
    );
    for (final brick in row) {
      _destroy(brick);
    }
    _sweepDead();
  }

  // ------------------------------------------------------------------ actions

  /// Banks or spends a power-up. Reached from the menu and from gift tiles, so
  /// both routes share one implementation and one set of toasts.
  void usePower(PowerUp power) {
    if (mode == GameMode.over) return;
    switch (power) {
      case PowerUp.balls:
        totalBalls = math.min(RicochetTuning.maxBalls, totalBalls + 10);
        _addText(
          Board.width / 2,
          RicochetTuning.toastY,
          strings.plusBalls(10),
          RicochetColors.info,
          1,
          16,
        );
        RicochetAudioService.instance.play(RicochetSfx.plus);
      case PowerUp.pierce:
        pierceCharges++;
        _armToast(strings.pierceArmed, RicochetColors.pierceLight);
      case PowerUp.bomb:
        bombCharges++;
        _armToast(strings.bombArmed, RicochetColors.blastLight);
      case PowerUp.clearRow:
        clearLowestRow();
    }
    _sweepDead();
    _markHudDirty();
  }

  /// Fires the volley. Banked charges move into the volley here, so the chips
  /// keep showing what is still to be spent while it plays out.
  void fire(Offset direction) {
    if (mode != GameMode.aiming) return;
    _volleyDirection = direction;
    _pierceLeft = pierceCharges;
    _bombLeft = bombCharges;
    pierceCharges = 0;
    bombCharges = 0;
    _pendingShots = math.min(totalBalls, RicochetTuning.volleyCap);
    _volleyAccumulator = RicochetTuning.staggerSeconds;
    _volleyElapsed = 0;
    _firstLandX = null;
    _firedOnce = true;
    speedMultiplier = 1;
    _autoSped = false;
    mode = GameMode.shooting;
    RicochetAudioService.instance.play(RicochetSfx.launch);
    _markHudDirty();
  }

  /// Pulls every ball home at once, so a shot that found a slow corner can
  /// never trap the player.
  void recallBalls() {
    if (mode != GameMode.shooting) return;
    for (final ball in balls) {
      _burst(ball.x, ball.y, RicochetColors.ballTrail, 6);
    }
    balls.clear();
    _pendingShots = 0;
    _firstLandX = null;
    _addText(
      Board.width / 2,
      RicochetTuning.toastY,
      strings.recalled,
      RicochetColors.ballTrail,
      1,
      16,
    );
    _markHudDirty();
  }

  /// Each press stacks another boost, up to [RicochetTuning.maxSpeed].
  void boostSpeed() {
    if (mode != GameMode.shooting ||
        speedMultiplier >= RicochetTuning.maxSpeed) {
      return;
    }
    speedMultiplier = math.min(
      RicochetTuning.maxSpeed,
      speedMultiplier + RicochetTuning.speedBoostStep,
    );
    _addText(
      Board.width / 2,
      RicochetTuning.toastY,
      strings.speedBoost(speedMultiplier),
      RicochetColors.bonus,
      1,
      17,
    );
    RicochetAudioService.instance.play(RicochetSfx.arm);
    _markHudDirty();
  }

  void _startShift() {
    shiftProgress = 0;
    mode = GameMode.shifting;
    _markHudDirty();
  }

  void _finalizeShift() {
    _sweepDead();
    for (final brick in bricks) {
      brick.y += Board.cell;
    }
    _markGridDirty();
    for (final pickup in pickups) {
      pickup.y += Board.cell;
    }
    pickups.removeWhere((p) => p.y > Board.dangerY);
    shiftProgress = 0;

    if (bricks.any((b) => b.y + b.height > Board.dangerY)) {
      _gameOver();
      return;
    }

    if (bricks.isEmpty) {
      final bonus = 100 * level;
      score += bonus;
      _recordBest();
      _addText(
        Board.width / 2,
        Board.height / 2,
        strings.scorePopup(bonus),
        RicochetColors.bonus,
        1.4,
        24,
      );
      _showBanner(level + 1);
      totalBalls = math.min(totalBalls + 2, RicochetTuning.volleyCap);
      RicochetAudioService.instance.play(RicochetSfx.levelClear);
      _betweenTimer = 1.1;
      mode = GameMode.between;
    } else {
      mode = GameMode.aiming;
    }
    _markHudDirty();
  }

  void _gameOver() {
    mode = GameMode.over;
    _recordBest();
    RicochetAudioService.instance.play(RicochetSfx.gameOver);
    // The in-progress save is replaced by the level's checkpoint, so *Retry
    // Level* has a board to restore and a resumed app never lands on a dead run.
    final checkpoint = _checkpoint;
    if (checkpoint != null) {
      unawaited(_store.writeSave(checkpoint));
    } else {
      unawaited(_store.clearSave());
    }
    _saveDirty = false;
    _markHudDirty();
  }

  /// Replays the current level from exactly the board it started with.
  Future<void> retryLevel() async {
    final data = _checkpoint ?? await _store.loadCheckpoint();
    if (data == null || _disposed) {
      await resetGame();
      return;
    }
    if (!_hydrate(data)) {
      await resetGame();
      return;
    }
    _showBanner(level);
    mode = GameMode.aiming;
    RicochetAudioService.instance.play(RicochetSfx.arm);
    _markHudDirty();
  }

  /// Starts over from level 1, discarding the saved run.
  Future<void> resetGame() async {
    bricks.clear();
    pickups.clear();
    balls.clear();
    particles.clear();
    texts.clear();
    rings.clear();
    level = 1;
    score = 0;
    totalBalls = 1;
    originX = Board.width / 2;
    pierceCharges = 0;
    bombCharges = 0;
    _pierceLeft = 0;
    _bombLeft = 0;
    speedMultiplier = 1;
    _autoSped = false;
    _pendingShots = 0;
    _firstLandX = null;
    aiming = false;
    aimPoint = null;
    _saveDirty = false;
    await _store.clearSave();
    _generateLevel(1);
    _showBanner(1);
    mode = GameMode.aiming;
    _markHudDirty();
  }

  // -------------------------------------------------------------------- aiming

  /// Turns a drag point into a unit launch direction, clamped away from
  /// horizontal so no shot can crawl along the floor forever.
  Offset aimDirection(Offset point) {
    final dx = point.dx - originX;
    var dy = point.dy - Board.launchY;
    if (dy > -14) dy = -14;
    var angle = math.atan2(dy, dx);
    const m = RicochetTuning.minAngle;
    if (angle > -m) angle = dx < 0 ? -math.pi + m : -m;
    if (angle < -math.pi + m) angle = -math.pi + m;
    return Offset(math.cos(angle), math.sin(angle));
  }

  /// The dashed preview path: the same wall bounces the real ball takes, cut
  /// short at the first brick it would reach.
  List<Offset> previewTrajectory(Offset direction) {
    final points = <Offset>[Offset(originX, Board.launchY)];
    var px = originX;
    var py = Board.launchY;
    var vx = direction.dx;
    var vy = direction.dy;
    const step = 6.0;
    final offset = mode == GameMode.shifting ? rowShiftOffset : 0.0;

    for (var i = 0; i < 420; i++) {
      px += vx * step;
      py += vy * step;
      if (px < Board.ballRadius) {
        px = Board.ballRadius;
        vx = vx.abs();
      }
      if (px > Board.width - Board.ballRadius) {
        px = Board.width - Board.ballRadius;
        vx = -vx.abs();
      }
      if (py < Board.ballRadius) {
        py = Board.ballRadius;
        vy = vy.abs();
      }
      var struck = false;
      // Query the grid at the *unshifted* point rather than shifting every
      // brick: the two are the same test, and this one is bucketed.
      for (final brick in _bricksNear(px, py - offset)) {
        if (brick.dead) continue;
        if (px > brick.x - Board.ballRadius &&
            px < brick.x + brick.width + Board.ballRadius &&
            py > brick.y + offset - Board.ballRadius &&
            py < brick.y + offset + brick.height + Board.ballRadius) {
          struck = true;
          break;
        }
      }
      if (struck) {
        points.add(Offset(px, py));
        break;
      }
      if (i % 3 == 0) points.add(Offset(px, py));
    }
    return points;
  }

  /// How far the board is currently drawn below its logical position, easing
  /// the between-turns row drop.
  double get rowShiftOffset {
    if (mode != GameMode.shifting) return 0;
    final t = shiftProgress.clamp(0.0, 1.0);
    return (1 - (1 - t) * (1 - t)) * Board.cell;
  }

  void beginAim(Offset point) {
    if (mode != GameMode.aiming) return;
    aiming = true;
    _setAim(point);
  }

  void updateAim(Offset point) {
    if (!aiming) return;
    _setAim(point);
  }

  void _setAim(Offset point) {
    aimPoint = point;
    final direction = aimDirection(point);
    _aimAngle = math.atan2(direction.dy, direction.dx);
  }

  void releaseAim(Offset point) {
    if (!aiming) return;
    aiming = false;
    aimPoint = null;
    fire(aimDirection(point));
  }

  void cancelAim() {
    aiming = false;
    aimPoint = null;
  }

  /// Swings the keyboard sight by [radians] and shows it. Aim is *held* between
  /// presses — a key player lines the shot up over several frames and fires
  /// with [fireAimed], where a finger does both in one gesture.
  void rotateAim(double radians) {
    if (mode != GameMode.aiming) return;
    const m = RicochetTuning.minAngle;
    _aimAngle = (_aimAngle + radians).clamp(-math.pi + m, -m);
    aiming = true;
    // The sight is a point on the aim ray, so the painter and the pointer path
    // stay one code path.
    aimPoint = Offset(
      originX + math.cos(_aimAngle) * _aimReach,
      Board.launchY + math.sin(_aimAngle) * _aimReach,
    );
  }

  static const double _aimReach = 160;

  /// Fires the shot the keyboard is currently sighting, arming one first when
  /// the player has not touched the sight yet.
  void fireAimed() {
    if (mode != GameMode.aiming) return;
    if (!aiming) rotateAim(0);
    final point = aimPoint;
    if (point != null) releaseAim(point);
  }

  // ------------------------------------------------------------------ effects

  void _stepEffects(double dt) {
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 500 * dt;
      p.life -= dt;
      if (p.life <= 0) particles.removeAt(i);
    }
    for (var i = texts.length - 1; i >= 0; i--) {
      final t = texts[i];
      t.y -= 42 * dt;
      t.life -= dt;
      if (t.life <= 0) texts.removeAt(i);
    }
    for (var i = rings.length - 1; i >= 0; i--) {
      final r = rings[i];
      r.radius += (r.maxRadius - r.radius) * math.min(1, dt * 9);
      r.life -= dt * 2.4;
      if (r.life <= 0) rings.removeAt(i);
    }
    for (final brick in bricks) {
      if (brick.flash > 0) brick.flash = math.max(0, brick.flash - dt * 5);
    }
  }

  void _addText(
    double x,
    double y,
    String text,
    Color color,
    double life,
    double size,
  ) {
    texts.add(
      FloatingText(
        x: x,
        y: y,
        text: text,
        color: color,
        life: life,
        maxLife: life,
        size: size,
      ),
    );
  }

  void _burst(double x, double y, Color color, int count) {
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 60 + _random.nextDouble() * 240;
      particles.add(
        Particle(
          x: x,
          y: y,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 60,
          life: 0.5 + _random.nextDouble() * 0.35,
          maxLife: 0.85,
          color: color,
          size: 2 + _random.nextDouble() * 3,
        ),
      );
    }
  }

  void _showBanner(int forLevel) {
    bannerLevel = forLevel;
    bannerTimer = 1.4;
  }

  // -------------------------------------------------------------- persistence

  void _markHudDirty() {
    _saveDirty = true;
    _hud.ping();
  }

  void _recordBest() {
    if (score <= best) return;
    best = score;
    unawaited(_store.saveBest(best));
  }

  void _generateLevel(int forLevel) {
    final layout = _generator.generate(forLevel);
    bricks
      ..clear()
      ..addAll(layout.bricks);
    _markGridDirty();
    pickups
      ..clear()
      ..addAll(layout.pickups);
    _captureCheckpoint();
  }

  /// Snapshots the board exactly as the level began, for *Retry Level*.
  void _captureCheckpoint() {
    _checkpoint = _serialize();
    unawaited(_store.writeCheckpoint(_checkpoint!));
  }

  /// Writes the run so closing the app mid-level resumes where it left off.
  /// Called on a timer while dirty, and once on dispose.
  Future<void> saveNow() => _saveNow();

  Future<void> _saveNow() async {
    if (mode == GameMode.over) {
      _saveDirty = false;
      return;
    }
    _saveDirty = false;
    await _store.writeSave(_serialize());
  }

  Map<String, dynamic> _serialize() => {
    'v': 1,
    'level': level,
    'score': score,
    'best': best,
    'totalBalls': totalBalls,
    'originX': originX,
    'bricks': [
      for (final brick in bricks)
        {
          'x': brick.x.round(),
          'y': brick.y.round(),
          'hp': brick.hp,
          'mh': brick.maxHp,
          't': brick.type.name,
        },
    ],
    'pk': [
      for (final pickup in pickups)
        {
          'x': pickup.x.round(),
          'y': pickup.y.round(),
          'r': pickup.radius,
          's': pickup.seed,
        },
    ],
  };

  /// Restores a serialized board. Returns false when the payload is not a
  /// recognizable save, so the caller can fall back to a fresh game. Individual
  /// bricks are validated and dropped rather than trusted — a save edited by
  /// hand must not be able to spawn a brick already past the danger line.
  bool _hydrate(Map<String, dynamic> data) {
    if (data['v'] != 1) return false;
    final savedLevel = data['level'];
    if (savedLevel is! int || savedLevel < 1) return false;

    level = savedLevel;
    score = (data['score'] as num?)?.toInt() ?? 0;
    best = math.max(best, (data['best'] as num?)?.toInt() ?? 0);
    totalBalls = ((data['totalBalls'] as num?)?.toInt() ?? 1).clamp(
      1,
      RicochetTuning.maxBalls,
    );
    originX = ((data['originX'] as num?)?.toDouble() ?? Board.width / 2).clamp(
      Board.ballRadius + 4,
      Board.width - Board.ballRadius - 4,
    );

    bricks.clear();
    for (final raw in (data['bricks'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final x = (raw['x'] as num?)?.toDouble();
      final y = (raw['y'] as num?)?.toDouble();
      final hp = (raw['hp'] as num?)?.toInt();
      if (x == null || y == null || hp == null || hp <= 0) continue;
      // Snap to the grid the buckets assume, so a hand-edited save cannot park
      // a brick between cells where no ball would ever look for it.
      final snappedX = (x / Board.cell).round() * Board.cell;
      final snappedY = (y / Board.cell).round() * Board.cell;
      if (snappedX < 0 || snappedX >= Board.width) continue;
      if (snappedY + Board.cell >= Board.dangerY) continue;
      bricks.add(
        Brick(
          uid: _uidSeq++,
          x: snappedX,
          y: snappedY,
          hp: hp,
          maxHp: (raw['mh'] as num?)?.toInt() ?? hp,
          type: TileType.fromId(raw['t'] as String?) ?? TileType.normal,
          flash: 0,
        ),
      );
    }
    _markGridDirty();

    pickups.clear();
    for (final raw in (data['pk'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final x = (raw['x'] as num?)?.toDouble();
      final y = (raw['y'] as num?)?.toDouble();
      if (x == null || y == null) continue;
      pickups.add(
        Pickup(
          x: x,
          y: y,
          radius: (raw['r'] as num?)?.toDouble() ?? 14,
          seed: (raw['s'] as num?)?.toDouble() ?? 0,
        ),
      );
    }

    balls.clear();
    particles.clear();
    texts.clear();
    rings.clear();
    _pendingShots = 0;
    _firstLandX = null;
    aiming = false;
    aimPoint = null;
    pierceCharges = 0;
    bombCharges = 0;
    _pierceLeft = 0;
    _bombLeft = 0;
    speedMultiplier = 1;
    _autoSped = false;
    shiftProgress = 0;
    _betweenTimer = 0;
    mode = GameMode.aiming;
    return true;
  }
}
