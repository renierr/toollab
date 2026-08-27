import 'package:flutter/material.dart';

import 'responsive_layout.dart';

/// Centers and caps its child once the available width passes a comfortable
/// reading measure. A list left to fill a maximized desktop window stretches
/// each row into one thin strip, with the icon and the trailing value at
/// opposite ends of the screen.
///
/// Wrap the scrollable, not the rows — capping each row would leave the
/// scrollbar and any background stripes at the far edge.
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
