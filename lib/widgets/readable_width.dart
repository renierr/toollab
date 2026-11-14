import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'responsive_layout.dart';

/// Centers and caps its child once the available width passes a comfortable
/// reading measure. A list left to fill a maximized desktop window stretches
/// each row into one thin strip, with the icon and the trailing value at
/// opposite ends of the screen.
///
/// For a scrollable use [ReadableScrollPadding]: wrapped here, its side
/// margins would not scroll.
class ReadableWidth extends StatelessWidget {
  final Widget child;

  /// Overrides [Breakpoints.readableContent] for content that reads well
  /// wider (a table) or narrower (a settings column).
  final double? maxWidth;

  /// Grows the cap with the available width, from [minWidth] up to [maxWidth].
  final double? widthFactor;
  final double? minWidth;

  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth,
    this.widthFactor,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = _readableCap(
          constraints.maxWidth,
          maxWidth,
          widthFactor,
          minWidth,
        );
        if (constraints.maxWidth <= cap) return child;
        return Center(
          child: SizedBox(width: cap, child: child),
        );
      },
    );
  }
}

/// [ReadableWidth] for a scrollable that must also scroll from its side
/// margins: the cap becomes horizontal padding inside the full-width scrollable.
class ReadableScrollPadding extends StatelessWidget {
  final double? maxWidth;
  final double? widthFactor;
  final double? minWidth;
  final EdgeInsets padding;
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  const ReadableScrollPadding({
    super.key,
    this.maxWidth,
    this.widthFactor,
    this.minWidth,
    this.padding = EdgeInsets.zero,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = _readableCap(
          constraints.maxWidth,
          maxWidth,
          widthFactor,
          minWidth,
        );
        final side = math.max(0.0, (constraints.maxWidth - cap) / 2);
        return builder(
          context,
          padding + EdgeInsets.symmetric(horizontal: side),
        );
      },
    );
  }
}

double _readableCap(
  double available,
  double? maxWidth,
  double? widthFactor,
  double? minWidth,
) {
  final cap = maxWidth ?? Breakpoints.readableContent;
  if (widthFactor == null || !available.isFinite) return cap;
  final floor = math.min(minWidth ?? 0, cap);
  return (available * widthFactor).clamp(floor, cap);
}
