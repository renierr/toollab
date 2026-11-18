import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tool_lab/helpers/key_guards.dart';

/// Shift+Up / Down reading scroll: a fifth of the viewport per press, without
/// moving the focus. Held keys chain from the pending target, not the
/// mid-animation offset, so repeats keep a steady pace.
class ScrollNudger {
  double? _target;

  void nudge(ScrollController controller, int direction) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final from = _target ?? position.pixels;
    final target = (from + direction * position.viewportDimension * 0.2).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _target = target;
    unawaited(
      controller
          .animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (_target == target) _target = null;
          }),
    );
  }

  static int? directionOf(KeyEvent event) {
    if (event is KeyUpEvent ||
        !HardwareKeyboard.instance.isShiftPressed ||
        !KeyGuards.plain) {
      return null;
    }
    return switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => null,
    };
  }
}
