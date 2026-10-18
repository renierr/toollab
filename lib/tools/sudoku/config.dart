import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_model.dart';
import 'package:tool_lab/theme/theme.dart';

import 'sudoku_page.dart';
import 'sudoku_state.dart';

class SudokuTool {
  SudokuTool._();

  static ToolModel get config => ToolModel(
    id: 'sudoku',
    name: 'Sudoku',
    description:
        'Classic 9x9 Sudoku with endless puzzles and difficulty levels',
    icon: Icons.grid_3x3,
    route: '/sudoku',
    accentColor: AppTheme.accentBlue,
    sectionId: 'games',
    nameL10n: (l10n) => l10n.toolNameSudoku,
    descriptionL10n: (l10n) => l10n.toolDescSudoku,
    createPage: (_) => const SudokuPage(),
    stateProviders: () => [
      ChangeNotifierProvider<SudokuState>(create: (_) => SudokuState()),
    ],
    androidProcessIsolated: false,
  );
}
