import 'package:flutter/material.dart';

/// Sudoku's own palette, with a light and a dark board picked by the app theme.
class SudokuColors {
  const SudokuColors._({
    required this.page,
    required this.board,
    required this.cell,
    required this.cellAlt,
    required this.cellLine,
    required this.boxLine,
    required this.given,
    required this.user,
    required this.note,
    required this.selected,
    required this.peer,
    required this.sameNumber,
    required this.conflict,
    required this.success,
    required this.numpad,
    required this.numpadDisabled,
  });

  final Color page;
  final Color board;
  final Color cell;
  final Color cellAlt;
  final Color cellLine;
  final Color boxLine;
  final Color given;
  final Color user;
  final Color note;
  final Color selected;
  final Color peer;
  final Color sameNumber;
  final Color conflict;
  final Color success;
  final Color numpad;
  final Color numpadDisabled;

  static const SudokuColors dark = SudokuColors._(
    page: Color(0xFF0B0D14),
    board: Color(0xFF171A26),
    cell: Color(0xFF1F2333),
    cellAlt: Color(0xFF252A3D),
    cellLine: Color(0xFF171A26),
    boxLine: Color(0xFFE2E8F0),
    given: Color(0xFF94A3B8),
    user: Color(0xFF7DD3FC),
    note: Color(0xFF94A3B8),
    selected: Color(0xFF3B82F6),
    peer: Color(0xFF27304A),
    sameNumber: Color(0xFF1E3A5F),
    conflict: Color(0xFFEF4444),
    success: Color(0xFF34D399),
    numpad: Color(0xFF232738),
    numpadDisabled: Color(0xFF151822),
  );

  static const SudokuColors light = SudokuColors._(
    page: Color(0xFFF1F5F9),
    board: Color(0xFFFFFFFF),
    cell: Color(0xFFFFFFFF),
    cellAlt: Color(0xFFF1F5F9),
    cellLine: Color(0xFFCBD5E1),
    boxLine: Color(0xFF0F172A),
    given: Color(0xFF1E293B),
    user: Color(0xFF2563EB),
    note: Color(0xFF64748B),
    selected: Color(0xFF3B82F6),
    peer: Color(0xFFE2E8F0),
    sameNumber: Color(0xFFBFDBFE),
    conflict: Color(0xFFDC2626),
    success: Color(0xFF059669),
    numpad: Color(0xFFE2E8F0),
    numpadDisabled: Color(0xFFF8FAFC),
  );

  static SudokuColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
