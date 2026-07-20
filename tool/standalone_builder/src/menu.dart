// ignore_for_file: avoid_print

import 'dart:io';

class TerminalMenu {
  /// Displays an interactive selection menu in the terminal.
  /// Returns the selected index, or null if canceled.
  static Future<int?> select({
    required String prompt,
    required List<String> options,
  }) async {
    if (options.isEmpty) return null;

    bool originalLineMode = true;
    bool originalEchoMode = true;
    bool supportsRawTerminal = true;

    try {
      originalLineMode = stdin.lineMode;
      originalEchoMode = stdin.echoMode;
      stdin.lineMode = false;
      stdin.echoMode = false;
    } catch (_) {
      supportsRawTerminal = false;
      try {
        stdin.lineMode = originalLineMode;
      } catch (_) {}
      try {
        stdin.echoMode = originalEchoMode;
      } catch (_) {}
      return _selectFallback(prompt, options);
    }

    try {
      int selectedIndex = 0;
      bool rendering = true;

      // Hide cursor
      stdout.write('\x1B[?25l');

      void render() {
        stdout.write('\x1B[36m?\x1B[0m \x1B[1m$prompt\x1B[22m\n');
        for (int i = 0; i < options.length; i++) {
          if (i == selectedIndex) {
            stdout.write('  \x1B[36m❯ ${options[i]}\x1B[0m\n');
          } else {
            stdout.write('    ${options[i]}\n');
          }
        }
      }

      void clear() {
        final linesToClear = options.length + 1;
        for (int i = 0; i < linesToClear; i++) {
          stdout.write('\x1B[1A\x1B[2K');
        }
      }

      render();

      while (rendering) {
        final bytes = stdin.readByteSync();
        if (bytes == 3) {
          // Ctrl+C
          clear();
          stdout.write('\x1B[?25h'); // Restore cursor
          if (supportsRawTerminal) {
            try {
              stdin.lineMode = originalLineMode;
              stdin.echoMode = originalEchoMode;
            } catch (_) {}
          }
          exit(0);
        } else if (bytes == 13 || bytes == 10) {
          // Enter key
          rendering = false;
        } else if (bytes == 27) {
          // Escape sequence (arrow keys)
          final nextByte1 = stdin.readByteSync();
          if (nextByte1 == 91) {
            final nextByte2 = stdin.readByteSync();
            if (nextByte2 == 65) {
              // Up Arrow
              clear();
              selectedIndex =
                  (selectedIndex - 1 + options.length) % options.length;
              render();
            } else if (nextByte2 == 66) {
              // Down Arrow
              clear();
              selectedIndex = (selectedIndex + 1) % options.length;
              render();
            }
          }
        }
      }

      // Restore cursor
      stdout.write('\x1B[?25h');

      // Clear menu and print final selection
      clear();
      stdout.write(
        '\x1B[32m✔\x1B[0m $prompt: \x1B[36m${options[selectedIndex]}\x1B[0m\n',
      );

      return selectedIndex;
    } finally {
      if (supportsRawTerminal) {
        try {
          stdin.lineMode = originalLineMode;
          stdin.echoMode = originalEchoMode;
        } catch (_) {}
      }
    }
  }

  static int? _selectFallback(String prompt, List<String> options) {
    stdout.write('\x1B[36m?\x1B[0m \x1B[1m$prompt\x1B[22m:\n');
    for (int i = 0; i < options.length; i++) {
      stdout.write('  ${i + 1}) ${options[i]}\n');
    }

    while (true) {
      stdout.write('Enter selection number (1-${options.length}): ');
      final input = stdin.readLineSync();
      if (input == null) return null; // EOF / Cancel

      final val = input.trim();
      if (val.toLowerCase() == 'q' ||
          val.toLowerCase() == 'exit' ||
          val.toLowerCase() == 'quit') {
        return null;
      }

      final index = int.tryParse(val);
      if (index != null && index >= 1 && index <= options.length) {
        final selectedIndex = index - 1;
        stdout.write(
          '\x1B[32m✔\x1B[0m $prompt: \x1B[36m${options[selectedIndex]}\x1B[0m\n',
        );
        return selectedIndex;
      }
      print(
        'Invalid selection. Please enter a number between 1 and ${options.length} (or type "q" to quit).',
      );
    }
  }
}
