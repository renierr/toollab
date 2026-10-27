import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/game_result_overlay.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';
import 'engine/sudoku_engine.dart';
import 'engine/sudoku_generator.dart';
import 'sudoku_colors.dart';
import 'sudoku_labels.dart';
import 'sudoku_state.dart';
import 'widgets/sudoku_board.dart';
import 'widgets/sudoku_difficulty_sheet.dart';
import 'widgets/sudoku_hud.dart';
import 'widgets/sudoku_numpad.dart';
import 'widgets/sudoku_pause_overlay.dart';
import 'widgets/sudoku_settings_sheet.dart';
import 'widgets/sudoku_stats_sheet.dart';

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key});

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> with DisposeCleanup {
  static const BoxConstraints _boardConstraints = BoxConstraints(
    maxWidth: 520,
    maxHeight: 520,
  );

  // A puzzle left untouched this long counts as abandoned, so the screen may sleep.
  static const Duration _idleScreenOff = Duration(minutes: 5);

  late final SudokuEngine _engine;
  late final SudokuState _settings;
  final ScreenOnRequest _screenOn = ScreenOnRequest();
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _engine = SudokuEngine();
    _settings = context.read<SudokuState>();
    _settings.addListener(_syncSettings);
    _engine.addListener(_syncScreenOn);
    onDispose(() => _settings.removeListener(_syncSettings));
    onDispose(() => _engine.removeListener(_syncScreenOn));
    onDispose(() => _idleTimer?.cancel());
    onDispose(() => _screenOn.set(false));
    onDispose(_engine.dispose);
    unawaited(_bootstrap());
  }

  // Engine notifies on every move (the clock ticks separately), so each call also restarts the idle window.
  void _syncScreenOn() {
    final playing = !_engine.paused && !_engine.completed;
    _idleTimer?.cancel();
    _idleTimer = playing
        ? Timer(_idleScreenOff, () => _screenOn.set(false))
        : null;
    _screenOn.set(playing);
  }

  Future<void> _bootstrap() async {
    await _settings.restore();
    await _engine.bootstrap();
  }

  void _syncSettings() => _engine.autoCheck = _settings.autoCheck;

  void _haptic(Future<void> Function() feedback) {
    if (_settings.hapticsEnabled) unawaited(feedback());
  }

  Future<void> _newGame([SudokuDifficulty? difficulty]) =>
      _engine.startNew(difficulty ?? _engine.difficulty);

  Future<void> _changeDifficulty() async {
    final picked = await SudokuDifficultySheet.show(
      context,
      current: _engine.difficulty,
    );
    if (picked != null) await _newGame(picked);
  }

  void _onCellTap(int idx) {
    _engine.selectCell(idx);
    _haptic(HapticFeedback.selectionClick);
  }

  Future<void> _onNumber(int v) async {
    await _engine.enterNumber(v);
    _haptic(HapticFeedback.lightImpact);
  }

  Future<void> _onHint() async {
    await _engine.hint();
    _haptic(HapticFeedback.mediumImpact);
  }

  void _togglePause() => _engine.paused ? _engine.resume() : _engine.pause();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = SudokuColors.of(context);
    final state = context.watch<SudokuState>();

    return ToolLayout(
      title: SudokuTool.config.localizedName(l10n),
      backgroundColor: colors.page,
      fullscreen: true,
      showFloatingBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded),
          tooltip: l10n.sudokuStats,
          onPressed: () => SudokuStatsSheet.show(context, _engine.stats),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: l10n.commonSettings,
          onPressed: () => SudokuSettingsSheet.show(context),
        ),
      ],
      child: ListenableBuilder(
        listenable: _engine,
        builder: (context, _) {
          final hud = SudokuHud(
            engine: _engine,
            showTimer: state.showTimer,
            onChangeDifficulty: _changeDifficulty,
            onTogglePause: _togglePause,
            onNewGame: _newGame,
          );
          final board = ConstrainedBox(
            constraints: _boardConstraints,
            child: SudokuBoard(
              engine: _engine,
              highlightConflicts: state.highlightConflicts,
              highlightSameNumber: state.highlightSameNumber,
              autoCheck: state.autoCheck,
              onCellTap: _onCellTap,
            ),
          );
          final numpad = SudokuNumpad(
            remaining: _engine.remaining,
            notesMode: _engine.notesMode,
            canUndo: _engine.canUndo,
            onNumber: _onNumber,
            onErase: _engine.erase,
            onToggleNotes: _engine.toggleNotesMode,
            onHint: _onHint,
            onUndo: _engine.undo,
            onAutoNotes: _engine.autoNotes,
            onClearNotes: _engine.clearNotes,
          );

          return Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => constraints.canSplit
                    ? Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: board,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 300,
                            child: Column(
                              children: [
                                hud,
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
                      )
                    : Column(
                        children: [
                          hud,
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: board,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: numpad,
                          ),
                        ],
                      ),
              ),
              if (_engine.paused) SudokuPauseOverlay(onResume: _engine.resume),
              if (_engine.completed)
                GameResultOverlay(
                  title: l10n.sudokuCompleted,
                  headline: formatSudokuTime(_engine.elapsed),
                  headlineColor: colors.success,
                  subtitle: _engine.mistakes == 0 && _engine.hintsUsed == 0
                      ? l10n.sudokuPerfectGame
                      : l10n.sudokuHintsUsed(_engine.hintsUsed),
                  footnote: _engine.difficulty.label(l10n),
                  scrimColor: colors.board,
                  actions: [
                    GameResultAction(
                      label: l10n.sudokuPlayAgain,
                      icon: Icons.restart_alt_rounded,
                      onPressed: _newGame,
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
      ),
    );
  }
}
