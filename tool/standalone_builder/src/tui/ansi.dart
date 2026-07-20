/// ANSI escape codes for colors, styles, and cursor/screen control.
///
/// Kept dependency-free and deliberately small — only what the builder's TUI
/// uses. Rendering avoids the alternate-screen buffer (unreliable on some
/// Windows consoles); see [ansi_select_menu] for the in-place redraw approach.
class Ansi {
  const Ansi._();

  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const cyan = '\x1B[36m';
  static const green = '\x1B[32m';
  static const red = '\x1B[31m';
  static const yellow = '\x1B[33m';
  static const gray = '\x1B[90m';

  static const hideCursor = '\x1B[?25l';
  static const showCursor = '\x1B[?25h';
  static const saveCursor = '\x1B7'; // DECSC
  static const restoreCursor = '\x1B8'; // DECRC
  static const clearToLineEnd = '\x1B[K';
  static const clearBelow = '\x1B[J';

  /// Moves the cursor up [n] lines.
  static String cursorUp(int n) => '\x1B[${n}A';
}
