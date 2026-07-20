// ignore_for_file: avoid_print

import 'dart:io';

import 'ansi.dart';
import 'keys.dart';
import 'output.dart';

/// A Clack-style single-select menu.
///
/// When raw-key input is available it renders an interactive list with a
/// scrolling viewport (long lists stay navigable). Otherwise — native Windows
/// console, pipes, IDE consoles — it falls back to a paged numbered prompt that
/// still reaches every entry and echoes typed input.
class TerminalMenu {
  /// Shows the menu and returns the selected index, or null if the user quit /
  /// no options were given.
  static Future<int?> select({
    required String prompt,
    required List<String> options,
  }) async {
    if (options.isEmpty) return null;

    final raw = RawMode();
    if (!raw.enter()) return _selectFallback(prompt, options);

    var termRows = 24;
    try {
      if (stdout.hasTerminal) termRows = stdout.terminalLines;
    } catch (_) {}
    if (termRows < 6) termRows = 24;

    // Choice viewport height: terminal minus header + footer, never larger than
    // the list and always at least 1. (Avoids clamp() range errors for lists
    // smaller than the reserved chrome.)
    var maxVisible = termRows - 3;
    if (maxVisible < 1) maxVisible = 1;
    if (maxVisible > options.length) maxVisible = options.length;
    final blockRows = maxVisible + 2; // header + rows + footer

    var selected = 0;
    var windowStart = 0;
    var anchored = false;

    void anchor() {
      stdout.write(Ansi.hideCursor);
      // Reserve the block now so the terminal scrolls before the anchor is
      // saved — otherwise a save near the bottom would drift and redraws smear.
      if (blockRows > 1) {
        stdout.write('\n' * (blockRows - 1));
        stdout.write(Ansi.cursorUp(blockRows - 1));
      }
      stdout.write(Ansi.saveCursor);
      anchored = true;
    }

    void draw() {
      if (selected < windowStart) windowStart = selected;
      if (selected >= windowStart + maxVisible) {
        windowStart = selected - maxVisible + 1;
      }
      final windowEnd = (windowStart + maxVisible).clamp(0, options.length);

      final b = StringBuffer(Ansi.restoreCursor);
      b.write(
        '${Ansi.cyan}?${Ansi.reset} ${Ansi.bold}$prompt${Ansi.reset} '
        '${Ansi.gray}(${selected + 1}/${options.length})${Ansi.reset}'
        '${Ansi.clearToLineEnd}\n',
      );
      for (var i = windowStart; i < windowEnd; i++) {
        if (i == selected) {
          b.write('${Ansi.cyan}❯ ${options[i]}${Ansi.reset}');
        } else {
          b.write('  ${options[i]}');
        }
        b.write('${Ansi.clearToLineEnd}\n');
      }
      final more = <String>[
        if (windowStart > 0) '↑ more',
        if (windowEnd < options.length) '↓ more',
      ].join('  ');
      final navPrefix = more.isEmpty ? '' : '$more  •  ';
      b.write(
        '${Ansi.gray}$navPrefix↑/↓ move • PgUp/PgDn • enter select • '
        'q quit${Ansi.reset}${Ansi.clearToLineEnd}',
      );
      stdout.write(b.toString());
    }

    void cleanup() {
      if (anchored) stdout.write('${Ansi.restoreCursor}${Ansi.clearBelow}');
      stdout.write(Ansi.showCursor);
      raw.restore();
    }

    anchor();
    draw();

    try {
      while (true) {
        switch (readKey()) {
          case ConsoleKey.ctrlC:
            cleanup();
            exit(0);
          case ConsoleKey.quit:
            cleanup();
            return null;
          case ConsoleKey.enter:
            cleanup();
            Tui.success(
              '$prompt: ${Ansi.cyan}${options[selected]}${Ansi.reset}',
            );
            return selected;
          case ConsoleKey.up:
            selected = (selected - 1 + options.length) % options.length;
            draw();
          case ConsoleKey.down:
            selected = (selected + 1) % options.length;
            draw();
          case ConsoleKey.pageUp:
            selected = (selected - maxVisible).clamp(0, options.length - 1);
            draw();
          case ConsoleKey.pageDown:
            selected = (selected + maxVisible).clamp(0, options.length - 1);
            draw();
          case ConsoleKey.home:
            selected = 0;
            draw();
          case ConsoleKey.end:
            selected = options.length - 1;
            draw();
          case ConsoleKey.other:
            break;
        }
      }
    } catch (_) {
      cleanup();
      rethrow;
    }
  }

  /// Numbered menu used when raw-key input is unavailable. Pages long lists so
  /// every entry is reachable, and relies on cooked-mode input so typing echoes.
  static int? _selectFallback(String prompt, List<String> options) {
    const pageSize = 20;
    final pageCount = (options.length / pageSize).ceil();
    var page = 0;

    while (true) {
      final start = page * pageSize;
      final end = (start + pageSize).clamp(0, options.length);

      stdout.write(
        '\n${Ansi.cyan}?${Ansi.reset} ${Ansi.bold}$prompt${Ansi.reset}',
      );
      if (pageCount > 1) {
        stdout.write(' ${Ansi.gray}(page ${page + 1}/$pageCount)${Ansi.reset}');
      }
      stdout.write('\n');
      for (var i = start; i < end; i++) {
        final num = (i + 1).toString().padLeft(2);
        stdout.write('  ${Ansi.gray}$num)${Ansi.reset} ${options[i]}\n');
      }

      final nav = <String>[
        if (page < pageCount - 1) 'n=next',
        if (page > 0) 'p=prev',
        'q=quit',
      ].join(', ');
      stdout.write(
        '${Ansi.gray}Enter 1-${options.length} ($nav):${Ansi.reset} ',
      );

      final input = stdin.readLineSync();
      if (input == null) return null; // EOF

      final val = input.trim().toLowerCase();
      if (val == 'q' || val == 'exit' || val == 'quit') return null;
      if (val == 'n' && page < pageCount - 1) {
        page++;
        continue;
      }
      if (val == 'p' && page > 0) {
        page--;
        continue;
      }

      final index = int.tryParse(val);
      if (index != null && index >= 1 && index <= options.length) {
        final selectedIndex = index - 1;
        Tui.success(
          '$prompt: ${Ansi.cyan}${options[selectedIndex]}${Ansi.reset}',
        );
        return selectedIndex;
      }
      Tui.warn(
        'Enter a number between 1 and ${options.length} (or q to quit).',
      );
    }
  }
}
