import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/theme/theme.dart';

/// Draws a focus ring around [child] whenever it or one of its descendants is
/// focused. Material's default focus overlay is far too subtle across a room,
/// so TV builds need an outline a viewer can follow from the sofa.
///
/// The ring only appears while [KeyboardNavigation.active] says the user is
/// navigating by keyboard or D-pad, so touch and mouse use is unchanged.
///
/// When [onLongPress] is provided, holding the remote's OK / Select / Enter key
/// for [kLongPressTimeout] invokes [onLongPress], while a short press invokes
/// [onTap] on release instead of firing immediately on key-down.
/// Whether focus is being moved by keyboard or D-pad. Desktop reports the
/// traditional highlight mode for mouse use too, so [TvNavigationScope] sets
/// this from the last input instead. Without a scope it stays true.
abstract final class KeyboardNavigation {
  static final ValueNotifier<bool> active = ValueNotifier<bool>(true);
}

class FocusOutline extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FocusOutline({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.width = 3,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<FocusOutline> {
  bool _focused = false;
  bool _showRing = false;
  Timer? _longPressTimer;
  bool _activationKeyDown = false;
  bool _longPressFired = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_syncHighlightMode);
    KeyboardNavigation.active.addListener(_syncHighlightMode);
  }

  @override
  void dispose() {
    _cancelLongPressTimer();
    KeyboardNavigation.active.removeListener(_syncHighlightMode);
    FocusManager.instance.removeListener(_syncHighlightMode);
    super.dispose();
  }

  static bool _isKeyboardFocus() =>
      KeyboardNavigation.active.value &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  /// Nested outlines keep only the innermost ring lit, so a card around a
  /// focusable media tile does not show both rings at once.
  bool get _ownsPrimaryFocus {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return false;
    return context.findAncestorWidgetOfExactType<FocusOutline>() == widget;
  }

  static bool _isActivationKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA;

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _activationKeyDown = false;
    _longPressFired = false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onLongPress == null ||
        !_ownsPrimaryFocus ||
        !_isActivationKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _longPressTimer?.cancel();
      _activationKeyDown = true;
      _longPressFired = false;
      _longPressTimer = Timer(kLongPressTimeout, () {
        if (!mounted || !_activationKeyDown) return;
        _longPressFired = true;
        widget.onLongPress?.call();
      });
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent && _activationKeyDown) {
      final firedLongPress = _longPressFired;
      _cancelLongPressTimer();
      if (!firedLongPress) {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          final primaryContext = FocusManager.instance.primaryFocus?.context;
          if (primaryContext != null) {
            Actions.maybeInvoke(primaryContext, const ActivateIntent());
          }
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _syncHighlightMode() {
    final showRing = _focused && _isKeyboardFocus() && _ownsPrimaryFocus;
    if (showRing == _showRing) return;
    setState(() => _showRing = showRing);
  }

  void _handleFocusChange(bool focused) {
    if (focused == _focused) return;
    if (!focused) _cancelLongPressTimer();
    _focused = focused;
    _showRing = focused && _isKeyboardFocus() && _ownsPrimaryFocus;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
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
