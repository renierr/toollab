import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../x_keys.dart';

/// Backspace leaves the page, unless a text field has the focus. A scope of
/// its own keeps the keys coming even when nothing inside is focused yet.
class XBackKey extends StatelessWidget {
  final Widget child;

  const XBackKey({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            !XKeys.isBack(event.logicalKey) ||
            XKeys.typing) {
          return KeyEventResult.ignored;
        }
        unawaited(Navigator.of(context).maybePop());
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
