import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Guards for single-letter shortcuts.
abstract final class XKeys {
  /// No Ctrl / Alt / Meta held, so system and app shortcuts pass through.
  static bool get plain {
    final keyboard = HardwareKeyboard.instance;
    return !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed;
  }

  /// A text field has the focus, so letters and Backspace are typing.
  static bool get typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  static bool isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.backspace ||
      key == LogicalKeyboardKey.browserBack;
}
