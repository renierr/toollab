import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/key_guards.dart';

/// Escape, Backspace and Browser Back leave the page, unless a text field has
/// the focus. A scope of its own keeps the keys coming even when nothing
/// inside is focused yet.
class BackKeyScope extends StatelessWidget {
  final Widget child;

  const BackKeyScope({super.key, required this.child});

  static bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.backspace ||
      key == LogicalKeyboardKey.browserBack;

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            !_isBack(event.logicalKey) ||
            KeyGuards.typing) {
          return KeyEventResult.ignored;
        }
        unawaited(Navigator.of(context).maybePop());
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
