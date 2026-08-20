import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

import 'renpho_body_metrics.dart';
import 'renpho_colors.dart';

/// A limb as a rounded bar rotated around its top end, so path, hit test and
/// callout anchor all follow from the same five numbers.
class _Limb {
  final double topX;
  final double topY;
  final double length;
  final double width;
  final double angleDeg;

  const _Limb(this.topX, this.topY, this.length, this.width, this.angleDeg);

  Offset _top(Rect f) =>
      Offset(f.left + topX * f.width, f.top + topY * f.height);

  Matrix4 _rotation(Rect f) {
    final top = _top(f);
    return Matrix4.identity()
      ..translateByDouble(top.dx, top.dy, 0, 1)
      ..rotateZ(angleDeg * math.pi / 180)
      ..translateByDouble(-top.dx, -top.dy, 0, 1);
  }

  Path path(Rect f) {
    final top = _top(f);
    final w = width * f.width;
    final l = length * f.height;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(top.dx - w / 2, top.dy - w / 2, w, l + w / 2),
      Radius.circular(w / 2),
    );
    return (Path()..addRRect(bar)).transform(_rotation(f).storage);
  }

  Offset anchor(Rect f) => MatrixUtils.transformPoint(
    _rotation(f),
    _top(f) + Offset(0, length * f.height * 0.62),
  );
}

/// The front-view figure in a normalised box. The person faces the viewer, so
/// their left side is drawn on the right.
class RenphoBodyGeometry {
  RenphoBodyGeometry._();

  /// Width divided by height of the drawn figure.
  static const double aspect = 0.62;

  /// Height of one callout, and the room the trunk callout needs above the
  /// figure so it never covers the head.
  static const double calloutHeight = 62;
  static const double topBand = calloutHeight + 10;

  static const _limbs = <RenphoSegment, _Limb>{
    RenphoSegment.rightArm: _Limb(0.315, 0.205, 0.33, 0.082, 11),
    RenphoSegment.leftArm: _Limb(0.685, 0.205, 0.33, 0.082, -11),
    RenphoSegment.rightLeg: _Limb(0.437, 0.52, 0.43, 0.115, 4),
    RenphoSegment.leftLeg: _Limb(0.563, 0.52, 0.43, 0.115, -4),
  };

  static Rect figureRect(Size size) {
    final height = size.height - topBand;
    final width = math.min(height * aspect, size.width * 0.34);
    return Rect.fromLTWH((size.width - width) / 2, topBand, width, height);
  }

  static Path path(RenphoSegment segment, Rect f) =>
      segment == RenphoSegment.trunk ? _trunk(f) : _limbs[segment]!.path(f);

  static Path _trunk(Rect f) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          f.left + 0.335 * f.width,
          f.top + 0.175 * f.height,
          f.left + 0.665 * f.width,
          f.top + 0.555 * f.height,
        ),
        Radius.circular(0.035 * f.height),
      ),
    );

  /// Head plus neck — drawn, but not part of any measured segment.
  static Path headAndNeck(Rect f) => Path()
    ..addOval(
      Rect.fromCircle(
        center: Offset(f.left + 0.5 * f.width, f.top + 0.075 * f.height),
        radius: 0.062 * f.height,
      ),
    )
    ..addRect(
      Rect.fromLTRB(
        f.left + 0.455 * f.width,
        f.top + 0.125 * f.height,
        f.left + 0.545 * f.width,
        f.top + 0.20 * f.height,
      ),
    );

  /// Where a callout line touches the body.
  static Offset anchor(RenphoSegment segment, Rect f) =>
      segment == RenphoSegment.trunk
      ? Offset(f.left + 0.40 * f.width, f.top + 0.26 * f.height)
      : _limbs[segment]!.anchor(f);

  /// Vertical centre of a segment's callout, in the coordinates of the whole
  /// map area.
  static double calloutCenterY(
    RenphoSegment segment,
    Rect f,
  ) => switch (segment) {
    RenphoSegment.trunk => topBand / 2,
    RenphoSegment.leftArm || RenphoSegment.rightArm => f.top + 0.34 * f.height,
    RenphoSegment.leftLeg || RenphoSegment.rightLeg => f.top + 0.80 * f.height,
  };

  /// Where a segment's callout sits: limbs flank the figure, the trunk sits in
  /// the band above it because the torso is too narrow to label in place.
  static Rect calloutRect(RenphoSegment segment, Size size, double height) {
    final f = figureRect(size);
    if (segment == RenphoSegment.trunk) {
      final width = math.min(150.0, size.width - 32);
      return Rect.fromLTWH((size.width - width) / 2, 0, width, height);
    }
    return Rect.fromLTWH(
      onLeftSide(segment) ? 0 : f.right + 10,
      calloutCenterY(segment, f) - height / 2,
      f.left - 10,
      height,
    );
  }

  /// Segments of the body's right side are drawn — and labelled — on the left.
  static bool onLeftSide(RenphoSegment segment) =>
      segment == RenphoSegment.rightArm || segment == RenphoSegment.rightLeg;

  /// Muscle against the reference for that segment: at or above standard is
  /// the healthy case, so only a shortfall shifts the colour.
  static Color tint(double muscleOfStandardPercent) =>
      muscleOfStandardPercent >= 100
      ? RenphoColors.muscle
      : muscleOfStandardPercent >= 90
      ? AppTheme.statusAmber
      : AppTheme.statusRed;
}
