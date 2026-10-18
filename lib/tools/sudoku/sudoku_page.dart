import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/game_result_overlay.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';
import 'engine/sudoku_engine.dart';
import 'engine/sudoku_generator.dart';
import 'sudoku_colors.dart';
import 'sudoku_state.dart';
import 'widgets/sudoku_board.dart';
import 'widgets/sudoku_difficulty_sheet.dart';
import 'widgets/sudoku_numpad.dart';
import 'widgets/sudoku_settings_sheet.dart';
import 'widgets/sudoku_stats_sheet.dart';

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key});

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> with DisposeCleanup {
  late final SudokuEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = SudokuEngine();
    onDispose(_engine.dispose);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final state = context.read<SudokuState>();
    await state.restore();
    _engine.autoCheck = state.autoCheck;
    _engine.maxMistakes = state.maxMistakes;
    _engine.hintsPerGame = state.hintsPerGame;
    await _engine.bootstrap();
    if (mounted) setState(() {});
  }

  void _applySettings() {
    final state = context.read<SudokuState>();
    _engine.autoCheck = state.autoCheck;
    _engine.maxMistakes = state.maxMistakes;
    _engine.hintsPerGame = state.hintsPerGame;
  }

  Future<void> _newGame([SudokuDifficulty? d]) async {
    final diff = d ?? _engine.difficulty;
    _applySettings();
    _engine.setDifficulty(diff);
    await _engine.startNew(diff);
    if (mounted) setState(() {});
  }

  Future<void> _changeDifficulty() async {
    final picked = await SudokuDifficultySheet.show(context, current: _engine.difficulty);
    if (picked == null) return;
    await _newGame(picked);
  }

  void _onCellTap(int idx) {
    final state = context.read<SudokuState>();
    _engine.selectCell(idx);
    if (state.hapticsEnabled) HapticFeedback.selectionClick();
    setState(() {});
  }

  Future<void> _onNumber(int v) async {
    final state = context.read<SudokuState>();
    await _engine.enterNumber(v);
    if (state.hapticsEnabled) HapticFeedback.lightImpact();
    setState(() {});
  }

  Future<void> _onErase() async {
    await _engine.erase();
    setState(() {});
  }

  Future<void> _onHint() async {
    final state = context.read<SudokuState>();
    await _engine.hint();
    if (state.hapticsEnabled) HapticFeedback.mediumImpact();
    setState(() {});
  }

  Future<void> _onUndo() async {
    await _engine.undo();
    setState(() {});
  }

  Future<void> _onAutoNotes() async {
    await _engine.autoNotes();
    setState(() {});
  }

  Future<void> _onClearNotes() async {
    await _engine.clearNotes();
    setState(() {});
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _diffLabel(SudokuDifficulty d, AppLocalizations l10n) {
    switch (d) {
      case SudokuDifficulty.easy:
        return l10n.sudokuDifficultyEasy;
      case SudokuDifficulty.medium:
        return l10n.sudokuDifficultyMedium;
      case SudokuDifficulty.hard:
        return l10n.sudokuDifficultyHard;
      case SudokuDifficulty.expert:
        return l10n.sudokuDifficultyExpert;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SudokuState>();

    return ToolLayout(
      title: SudokuTool.config.localizedName(l10n),
      backgroundColor: SudokuColors.page,
      fullscreen: true,
      showFloatingBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded),
          tooltip: l10n.sudokuStats,
          onPressed: () => SudokuStatsSheet.show(context, _engine),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.commonSettings,
          onPressed: () => SudokuSettingsSheet.show(context),
        ),
      ],
      child: AnimatedBuilder(
        animation: _engine,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final canSplit = constraints.canSplit;

              final board = SudokuBoard(
                engine: _engine,
                highlightConflicts: state.highlightConflicts,
                highlightSameNumber: state.highlightSameNumber,
                autoCheck: state.autoCheck,
                onCellTap: _onCellTap,
              );

              final numpad = SudokuNumpad(
                engine: _engine,
                notesMode: _engine.notesMode,
                hintsRemaining: _engine.hintsRemaining,
                canUndo: _engine.canUndo,
                onNumber: _onNumber,
                onErase: _onErase,
                onToggleNotes: () {
                  _engine.toggleNotesMode();
                  setState(() {});
                },
                onHint: _onHint,
                onUndo: _onUndo,
                onAutoNotes: _onAutoNotes,
                onClearNotes: _onClearNotes,
              );

              Widget content;
              if (canSplit) {
                content = Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
                            child: board,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: Column(
                        children: [
                          _buildHud(l10n, state),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: numpad,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                content = Column(
                  children: [
                    _buildHud(l10n, state),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
                            child: board,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: numpad,
                    ),
                  ],
                );
              }

              return Stack(
                children: [
                  content,
                  if (_engine.paused)
                    _PauseOverlay(
                      onResume: () {
                        _engine.resume();
                        setState(() {});
                      },
                      l10n: l10n,
                    ),
                  if (_engine.completed)
                    GameResultOverlay(
                      title: l10n.sudokuCompleted,
                      headline: _fmt(_engine.elapsed),
                      headlineColor: SudokuColors.success,
                      subtitle: _engine.mistakes == 0 &&
                              _engine.hintsRemaining == _engine.hintsPerGame
                          ? l10n.sudokuPerfectGame
                          : l10n.sudokuHintsUsed(
                              _engine.hintsPerGame - _engine.hintsRemaining,
                            ),
                      footnote: _diffLabel(_engine.difficulty, l10n),
                      scrimColor: SudokuColors.board,
                      actions: [
                        GameResultAction(
                          label: l10n.sudokuPlayAgain,
                          icon: Icons.restart_alt_rounded,
                          onPressed: () => _newGame(),
                        ),
                        GameResultAction(
                          label: l10n.sudokuChangeDifficulty,
                          icon: Icons.tune,
                          onPressed: _changeDifficulty,
                        ),
                      ],
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHud(AppLocalizations l10n, SudokuState state) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 96, top: 6, bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: _changeDifficulty,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SudokuColors.numpad,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _diffLabel(_engine.difficulty, l10n),
                    style: const TextStyle(color: SudokuColors.given, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 16, color: SudokuColors.note),
                ],
              ),
            ),
          ),
          if (state.showTimer)
            _InfoChip(icon: Icons.timer_outlined, label: _fmt(_engine.elapsed)),
          _InfoChip(
            icon: Icons.close,
            label: '${_engine.mistakes}',
            color: _engine.mistakes > 0 ? SudokuColors.conflict : null,
          ),
          IconButton(
            icon: Icon(_engine.paused ? Icons.play_arrow : Icons.pause),
            color: SudokuColors.given,
            tooltip: _engine.paused ? l10n.sudokuResume : l10n.sudokuPause,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              if (_engine.paused) {
                _engine.resume();
              } else {
                _engine.pause();
              }
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: SudokuColors.given,
            tooltip: l10n.sudokuNewGame,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _newGame(),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SudokuColors.numpad,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? SudokuColors.note),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color ?? SudokuColors.given, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final AppLocalizations l10n;
  const _PauseOverlay({required this.onResume, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onResume,
        child: Container(
          color: SudokuColors.page.withValues(alpha: 0.85),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_filled, size: 64, color: SudokuColors.given),
              const SizedBox(height: 12),
              Text(l10n.sudokuPausedTitle,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SudokuColors.given)),
              const SizedBox(height: 8),
              Text(l10n.sudokuTapToResume, style: const TextStyle(color: SudokuColors.note)),
            ],
          ),
        ),
      ),
    );
  }
}