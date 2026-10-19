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
  final double size;
  final bool lineRight;
  final bool lineBottom;
  final VoidCallback? onTap;

  const SudokuCell({
    super.key,
    required this.value,
    required this.given,
    required this.notes,
    required this.selected,
    required this.peer,
    required this.sameNumber,
    required this.conflict,
    required this.size,
    this.lineRight = false,
    this.lineBottom = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    final Color bg;
    if (selected) {
      bg = colors.selected.withValues(alpha: 0.35);
    } else if (conflict) {
      bg = colors.conflict.withValues(alpha: 0.18);
    } else if (sameNumber) {
      bg = colors.sameNumber;
    } else if (peer) {
      bg = colors.peer;
    } else {
      bg = given ? colors.cellAlt : colors.cell;
    }

    final line = BorderSide(color: colors.cellLine, width: 0.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: lineRight ? line : BorderSide.none,
            bottom: lineBottom ? line : BorderSide.none,
          ),
        ),
        alignment: Alignment.center,
        child: value != 0
            ? Text(
                '$value',
                style: TextStyle(
                  fontSize: size * 0.52,
                  fontWeight: given ? FontWeight.w600 : FontWeight.w500,
                  color: conflict
                      ? colors.conflict
                      : (given ? colors.given : colors.user),
                ),
              )
            : notes.isEmpty
            ? null
            : _NotesGrid(notes: notes, size: size, color: colors.note),
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  final Set<int> notes;
  final double size;
  final Color color;
  const _NotesGrid({
    required this.notes,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size * 0.26,
      color: color,
      fontWeight: FontWeight.w500,
      height: 1,
    );
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
                      style: style,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
