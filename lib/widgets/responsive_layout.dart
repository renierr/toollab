import 'package:flutter/material.dart';

/// Width tiers a layout can target: phone, tablet, desktop.
enum LayoutSizeClass { compact, medium, expanded }

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;

  /// Width at which two panes side by side beat stacking them. Higher than
  /// [mobileBreakpoint] because a split needs room for both halves, not just
  /// wider rows.
  static const double splitBreakpoint = 720.0;

  static LayoutSizeClass sizeClassFor(double width) {
    if (width >= tabletBreakpoint) return LayoutSizeClass.expanded;
    if (width >= mobileBreakpoint) return LayoutSizeClass.medium;
    return LayoutSizeClass.compact;
  }

  /// Window-width checks. Use these only for genuinely window-scoped
  /// decisions; a widget deciding its own layout should branch on the
  /// constraints it gets, not the window.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint &&
      MediaQuery.sizeOf(context).width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= mobileBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

/// Size tiers from the room a widget actually gets. Prefer these over the
/// window-scoped [ResponsiveLayout] statics whenever a widget is choosing its
/// own layout — inside a pane, drawer or split view the window is not the
/// space available.
extension ResponsiveConstraints on BoxConstraints {
  LayoutSizeClass get sizeClass => ResponsiveLayout.sizeClassFor(maxWidth);

  bool get isCompact => sizeClass == LayoutSizeClass.compact;
  bool get isMedium => sizeClass == LayoutSizeClass.medium;
  bool get isExpanded => sizeClass == LayoutSizeClass.expanded;

  /// Whether there is room to put two panes beside each other.
  bool get canSplit => maxWidth >= ResponsiveLayout.splitBreakpoint;
}
