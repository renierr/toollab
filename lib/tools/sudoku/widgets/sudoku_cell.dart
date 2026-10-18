import 'package:flutter/material.dart';

import '../sudoku_colors.dart';

class SudokuCell extends StatelessWidget {
  final int value;
  final bool given;
  final Set<int> notes;
  final bool selected;
  final bool peer;
  final bool sameNumber;
  final bool conflict;
  final bool hinted;
  final VoidCallback? onTap;
  final double size;
  final bool thickRight;
  final bool thickBottom;

  const SudokuCell({
    super.key,
    required this.value,
    required this.given,
    required this.notes,
    required this.selected,
    required this.peer,
    required this.sameNumber,
    required this.conflict,
    this.hinted = false,
    this.onTap,
    this.size = 40,
    this.thickRight = false,
    this.thickBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = given ? SudokuColors.cellAlt : SudokuColors.cell;
    if (selected) {
      bg = SudokuColors.selected.withValues(alpha: 0.35);
    } else if (conflict) {
      bg = SudokuColors.conflict.withValues(alpha: 0.18);
    } else if (sameNumber && value != 0) {
      bg = SudokuColors.sameNumber;
    } else if (peer) {
      bg = SudokuColors.peer;
    }

    Widget content;
    if (value != 0) {
      content = Text(
        '$value',
        style: TextStyle(
          fontSize: size * 0.52,
          fontWeight: given ? FontWeight.w600 : FontWeight.w500,
          color: conflict
              ? SudokuColors.conflict
              : (given
                    ? SudokuColors.given
                    : (hinted ? SudokuColors.hint : SudokuColors.user)),
        ),
      );
    } else if (notes.isNotEmpty) {
      content = _NotesGrid(notes: notes, size: size);
    } else {
      content = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(
              color: SudokuColors.board,
              width: thickRight ? 2.0 : 0.5,
            ),
            bottom: BorderSide(
              color: SudokuColors.board,
              width: thickBottom ? 2.0 : 0.5,
            ),
            left: const BorderSide(color: SudokuColors.board, width: 0.5),
            top: const BorderSide(color: SudokuColors.board, width: 0.5),
          ),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  final Set<int> notes;
  final double size;
  const _NotesGrid({required this.notes, required this.size});

  @override
  Widget build(BuildContext context) {
    final fs = size * 0.26;
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int r = 0; r < 3; r++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int c = 0; c < 3; c++)
                  SizedBox(
                    width: size / 3.2,
                    child: Text(
                      notes.contains(r * 3 + c + 1) ? '${r * 3 + c + 1}' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fs,
                        color: SudokuColors.note,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
