import 'package:flutter/material.dart';
import 'package:tool_lab/theme/theme.dart';

/// Draws a focus ring around [child] whenever it or one of its descendants is
/// focused. Material's default focus overlay is far too subtle across a room,
/// so TV builds need an outline a viewer can follow from the sofa.
///
/// The ring follows [FocusHighlightMode]: it only appears for keyboard or D-pad
/// focus, so touch and mouse use is unchanged.
class FocusOutline extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double width;

  const FocusOutline({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.width = 3,
  });

  @override
  State<FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<FocusOutline> {
  bool _focused = false;
  bool _showRing = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_syncHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_syncHighlightMode);
    super.dispose();
  }

  static bool _isKeyboardFocus() =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _syncHighlightMode() {
    final showRing = _focused && _isKeyboardFocus();
    if (showRing == _showRing) return;
    setState(() => _showRing = showRing);
  }

  void _handleFocusChange(bool focused) {
    if (focused == _focused) return;
    _focused = focused;
    _showRing = focused && _isKeyboardFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onFocusChange: _handleFocusChange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        foregroundDecoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: _showRing ? AppTheme.accentBlue : Colors.transparent,
            width: widget.width,
          ),
          boxShadow: _showRing
              ? [
                  BoxShadow(
                    color: AppTheme.accentBlue.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
