import 'package:flutter/services.dart';
import 'package:tool_lab/helpers/key_guards.dart';

abstract final class XKeys {
  static bool get plain => KeyGuards.plain;

  static bool get typing => KeyGuards.typing;

  static bool isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.backspace ||
      key == LogicalKeyboardKey.browserBack;
}
