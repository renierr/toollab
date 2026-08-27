import 'package:flutter/material.dart';

/// Width tiers a layout can target: phone, tablet, desktop.
enum LayoutSizeClass { compact, medium, expanded }

/// The width thresholds every responsive decision in the app is measured
/// against. Widgets do not read these directly — they branch on the
/// [ResponsiveConstraints] extension below, which is defined in terms of them.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 600.0;
  static const double tablet = 900.0;

  /// Width at which two panes side by side beat stacking them. Higher than
  /// [mobile] because a split needs room for both halves, not just wider rows.
  static const double split = 720.0;

  /// Width past which a single column of text or rows stops being readable and
  /// should be capped, or reflowed into more columns.
  static const double readableContent = 900.0;

  static LayoutSizeClass sizeClassFor(double width) {
    if (width >= tablet) return LayoutSizeClass.expanded;
    if (width >= mobile) return LayoutSizeClass.medium;
    return LayoutSizeClass.compact;
  }
}

/// Size tiers from the room a widget actually gets — inside a pane, drawer or
/// split view the window is not the space available, so every layout decision
/// starts from a [LayoutBuilder] and lands here.
extension ResponsiveConstraints on BoxConstraints {
  LayoutSizeClass get sizeClass => Breakpoints.sizeClassFor(maxWidth);

  bool get isCompact => sizeClass == LayoutSizeClass.compact;
  bool get isMedium => sizeClass == LayoutSizeClass.medium;
  bool get isExpanded => sizeClass == LayoutSizeClass.expanded;

  /// Whether there is room to put two panes beside each other.
  bool get canSplit => maxWidth >= Breakpoints.split;

  /// Whether a single column would stretch past a comfortable reading width.
  bool get isWiderThanReadable => maxWidth > Breakpoints.readableContent;
}
