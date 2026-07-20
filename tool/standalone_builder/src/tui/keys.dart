import 'dart:io';

import 'windows_console.dart';

/// A decoded key press relevant to menu navigation.
enum ConsoleKey {
  up,
  down,
  pageUp,
  pageDown,
  home,
  end,
  enter,
  quit,
  ctrlC,
  other,
}

/// Enables and restores raw terminal mode.
///
/// On Windows, Dart's `stdin.lineMode = false` fails (errno 87) on recent
/// builds, so we set the console mode directly via Win32 ([WindowsConsole]).
/// Elsewhere the standard `dart:io` line/echo toggles are used. [enter] rolls
/// back a half-applied change on failure and [restore] is idempotent.
class RawMode {
  final WindowsConsole? _windows = Platform.isWindows ? WindowsConsole() : null;

  bool _origLineMode = true;
  bool _origEchoMode = true;
  bool _dartActive = false;
  bool _windowsActive = false;

  bool get isActive => _dartActive || _windowsActive;

  /// Attempts to switch stdin into raw mode. Returns false if unsupported
  /// (real pipe, IDE console, or a console the OS won't switch).
  bool enter() {
    final windows = _windows;
    if (windows != null) {
      try {
        if (windows.enableRaw()) {
          _windowsActive = true;
          return true;
        }
      } catch (_) {}
      return false;
    }

    try {
      _origLineMode = stdin.lineMode;
      _origEchoMode = stdin.echoMode;
    } catch (_) {
      return false; // not a console we can read modes from
    }
    try {
      stdin.lineMode = false;
      stdin.echoMode = false;
      _dartActive = true;
      return true;
    } catch (_) {
      try {
        stdin.echoMode = _origEchoMode;
        stdin.lineMode = _origLineMode;
      } catch (_) {}
      return false;
    }
  }

  /// Restores the original console mode. Safe to call multiple times.
  void restore() {
    if (_windowsActive) {
      try {
        _windows!.restore();
      } catch (_) {}
      _windowsActive = false;
    }
    if (!_dartActive) return;
    _dartActive = false;
    try {
      stdin.lineMode = _origLineMode;
      stdin.echoMode = _origEchoMode;
    } catch (_) {}
  }
}

/// Reads and decodes one key press from raw stdin.
ConsoleKey readKey() {
  final c = stdin.readByteSync();
  if (c == -1) return ConsoleKey.quit; // EOF / stream closed
  if (c == 3) return ConsoleKey.ctrlC;
  if (c == 13 || c == 10) return ConsoleKey.enter;
  if (c == 113 || c == 81) return ConsoleKey.quit; // q / Q
  if (c == 107) return ConsoleKey.up; // k
  if (c == 106) return ConsoleKey.down; // j
  if (c == 27) {
    final c1 = stdin.readByteSync();
    if (c1 != 91 && c1 != 79) return ConsoleKey.other; // expect '[' or 'O'
    final c2 = stdin.readByteSync();
    switch (c2) {
      case 65:
        return ConsoleKey.up;
      case 66:
        return ConsoleKey.down;
      case 72:
        return ConsoleKey.home;
      case 70:
        return ConsoleKey.end;
      case 49: // '1~' Home
        stdin.readByteSync();
        return ConsoleKey.home;
      case 52: // '4~' End
        stdin.readByteSync();
        return ConsoleKey.end;
      case 53: // '5~' PageUp
        stdin.readByteSync();
        return ConsoleKey.pageUp;
      case 54: // '6~' PageDown
        stdin.readByteSync();
        return ConsoleKey.pageDown;
      default:
        return ConsoleKey.other;
    }
  }
  return ConsoleKey.other;
}
