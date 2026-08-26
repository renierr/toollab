import 'package:flutter/material.dart';

class ResponsiveAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? icon;
  final Color? backgroundColor;
  final double? elevation;
  final Clip clipBehavior;
  final MainAxisAlignment? actionsAlignment;
  final AlignmentGeometry? alignment;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final bool scrollable;

  const ResponsiveAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.backgroundColor,
    this.elevation,
    this.clipBehavior = Clip.none,
    this.actionsAlignment,
    this.alignment,
    this.shadowColor,
    this.surfaceTintColor,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 600;

    return AlertDialog(
      title: title,
      content: content,
      actions: actions,
      icon: icon,
      backgroundColor: backgroundColor,
      elevation: elevation,
      clipBehavior: clipBehavior,
      actionsAlignment: actionsAlignment,
      alignment: alignment,
      shadowColor: shadowColor,
      surfaceTintColor: surfaceTintColor,
      scrollable: scrollable,
      insetPadding: isNarrow
          ? const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0)
          : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      titlePadding: isNarrow
          ? const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0)
          : const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
      contentPadding: isNarrow
          ? const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0)
          : const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      actionsPadding: isNarrow
          ? const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0)
          : const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
    );
  }
}
