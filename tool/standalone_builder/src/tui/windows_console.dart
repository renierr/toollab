import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Puts the native Windows console into raw mode via `SetConsoleMode`.
///
/// Dart's own `stdin.lineMode = false` fails on modern Windows builds
/// (`StdinException errno 87 — invalid parameter`), so the interactive menu
/// can't get key-by-key input through the Dart API. Calling the Win32 console
/// API directly works: we disable line/echo/processed input and enable
/// virtual-terminal input so arrow keys arrive as ANSI escape sequences that
/// `stdin.readByteSync()` can read.
///
/// Uses only `dart:ffi` + `package:ffi` (no `win32` package — that conflicts
/// with the app's `share_plus`).
class WindowsConsole {
  // Console input mode flags (wincon.h).
  static const _enableProcessedInput = 0x0001;
  static const _enableLineInput = 0x0002;
  static const _enableEchoInput = 0x0004;
  static const _enableVirtualTerminalInput = 0x0200;

  // GetStdHandle(STD_INPUT_HANDLE) — (DWORD)-10 == 0xFFFFFFF6.
  static const _stdInputHandle = 0xFFFFFFF6;
  static const _invalidHandle = -1;

  late final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

  late final int Function(int) _getStdHandle = _kernel32
      .lookupFunction<IntPtr Function(Uint32), int Function(int)>(
        'GetStdHandle',
      );

  late final int Function(int, Pointer<Uint32>) _getConsoleMode = _kernel32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetConsoleMode');

  late final int Function(int, int) _setConsoleMode = _kernel32
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode',
      );

  int? _handle;
  int? _originalMode;

  /// Switches the console input to raw mode. Returns false if stdin is not a
  /// real console (pipe, mintty pty), leaving the terminal untouched.
  bool enableRaw() {
    final handle = _getStdHandle(_stdInputHandle);
    if (handle == 0 || handle == _invalidHandle) return false;

    final modePtr = calloc<Uint32>();
    try {
      if (_getConsoleMode(handle, modePtr) == 0) return false; // not a console
      final original = modePtr.value;
      var mode =
          original &
          ~(_enableLineInput | _enableEchoInput | _enableProcessedInput);
      mode |= _enableVirtualTerminalInput;
      if (_setConsoleMode(handle, mode) == 0) return false;

      _handle = handle;
      _originalMode = original;
      return true;
    } finally {
      calloc.free(modePtr);
    }
  }

  /// Restores the console input mode captured by [enableRaw].
  void restore() {
    final handle = _handle;
    final original = _originalMode;
    if (handle == null || original == null) return;
    _setConsoleMode(handle, original);
    _handle = null;
    _originalMode = null;
  }
}
