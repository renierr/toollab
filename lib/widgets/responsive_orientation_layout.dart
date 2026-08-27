import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// A widget that switches between a portrait and a landscape layout
/// based on the aspect ratio of the available constraints.
///
/// This is more robust than [MediaQuery.of(context).orientation] because it
/// respects the constraints of the parent (e.g. inside split-screens or dialogs).
class ResponsiveOrientationLayout extends StatelessWidget {
  /// Layout builder to use when the parent height is greater than or equal to width.
  final Widget portrait;

  /// Layout builder to use when the parent width is greater than height.
  final Widget landscape;

  /// Optional padding to wrap around the layout.
  final EdgeInsetsGeometry? padding;

  /// Minimum width required to use the landscape layout.
  /// If the available width is less than this value, falls back to portrait.
  final double minLandscapeWidth;

  const ResponsiveOrientationLayout({
    super.key,
    required this.portrait,
    required this.landscape,
    this.padding,
    this.minLandscapeWidth = Breakpoints.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            constraints.maxWidth > constraints.maxHeight &&
            constraints.maxWidth >= minLandscapeWidth;
        final child = isLandscape ? landscape : portrait;

        if (padding != null) {
          return Padding(padding: padding!, child: child);
        }
        return child;
      },
    );
  }
}
