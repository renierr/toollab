// ignore_for_file: avoid_print

import 'ansi.dart';

/// Styled status output helpers used across the builder CLI.
class Tui {
  const Tui._();

  static void info(String msg) => print('${Ansi.cyan}•${Ansi.reset} $msg');
  static void step(String msg) => print('${Ansi.gray}▸ $msg${Ansi.reset}');
  static void success(String msg) => print('${Ansi.green}✔${Ansi.reset} $msg');
  static void warn(String msg) => print('${Ansi.yellow}!${Ansi.reset} $msg');
  static void error(String msg) => print('${Ansi.red}✖${Ansi.reset} $msg');

  /// Runs [action], printing a start line and a ✔/✖ result line. No animation,
  /// so it is safe on every terminal (nothing to leave dangling on failure).
  static Future<T> task<T>(String label, Future<T> Function() action) async {
    print('${Ansi.gray}▸ $label…${Ansi.reset}');
    try {
      final result = await action();
      success(label);
      return result;
    } catch (_) {
      error('$label — failed');
      rethrow;
    }
  }
}
