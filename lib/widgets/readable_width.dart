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

  const ReadableWidth({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? Breakpoints.readableContent;

    return LayoutBuilder(
      builder: (context, constraints) {
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
  final EdgeInsets padding;
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  const ReadableScrollPadding({
    super.key,
    this.maxWidth,
    this.padding = EdgeInsets.zero,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? Breakpoints.readableContent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(0.0, (constraints.maxWidth - cap) / 2);
        return builder(
          context,
          padding + EdgeInsets.symmetric(horizontal: side),
        );
      },
    );
  }
}
