import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/game_hud.dart';
import 'package:tool_lab/widgets/game_result_overlay.dart';
import 'package:tool_lab/widgets/game_stat.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';
import 'engine/twenty48_audio.dart';
import 'engine/twenty48_direction.dart';
import 'engine/twenty48_engine.dart';
import 'twenty48_audio_service.dart';
import 'twenty48_colors.dart';
import 'twenty48_state.dart';
import 'widgets/twenty48_board.dart';
import 'widgets/twenty48_directional_input.dart';
import 'widgets/twenty48_settings_sheet.dart';

/// 2048's entry point: owns the engine, maps input onto it, and composes the
/// board, HUD and overlays.
///
/// There is no frame clock. The engine is a [ChangeNotifier] that fires once
/// per move, which is the only moment anything on screen can change.
class Twenty48Page extends StatefulWidget {
  const Twenty48Page({super.key});

  @override
  State<Twenty48Page> createState() => _Twenty48PageState();
}

class _Twenty48PageState extends State<Twenty48Page> with DisposeCleanup {
  final Twenty48Engine _engine = Twenty48Engine();

  /// A win is announced once. Dismissing it lets the run continue, because
  /// hitting 2048 with room left on the board is a milestone, not an ending.
  bool _winDismissed = false;

  @override
  void initState() {
    super.initState();
    onDispose(_engine.dispose);
    onDispose(() => unawaited(Twenty48AudioService.instance.releaseAll()));
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await context.read<Twenty48State>().restore();
    await Twenty48Sfx.load();
    await _engine.start();
    if (mounted) setState(() => _winDismissed = _engine.won);
  }

  void _move(Twenty48Direction direction) {
    final wasWon = _engine.won;
    if (!_engine.move(direction)) return;

    final haptics = context.read<Twenty48State>().hapticsEnabled;
    final merged = _engine.lastMergedValue;
    if (merged > 0) {
      Twenty48AudioService.instance.play(Twenty48Sfx.merge(merged));
      if (haptics) HapticFeedback.selectionClick();
    } else {
      Twenty48AudioService.instance.play(Twenty48Sfx.slide);
    }
    if (_engine.won && !wasWon) {
      Twenty48AudioService.instance.play(Twenty48Sfx.win);
    }
    if (_engine.isStuck) {
      Twenty48AudioService.instance.play(Twenty48Sfx.gameOver);
    }
  }

  void _undo() {
    if (!_engine.canUndo) return;
    _engine.undoMove();
    Twenty48AudioService.instance.play(Twenty48Sfx.undo);
  }

  void _newGame() {
    _engine.newGame();
    setState(() => _winDismissed = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<Twenty48State>();
    Twenty48AudioService.instance.setMasterVolume(state.soundEnabled ? 1 : 0);

    return ToolLayout(
      title: Twenty48Tool.config.localizedName(l10n),
      backgroundColor: Twenty48Colors.page,
      fullscreen: true,
      showFloatingBackButton: true,
      child: AnimatedBuilder(
        animation: _engine,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final hud = GameHud(
              vertical: constraints.canSplit,
              stats: [
                GameStat(
                  label: l10n.twenty48Score,
                  value: '${_engine.score}',
                  centered: true,
                ),
                GameStat(
                  label: l10n.twenty48Best,
                  value: '${_engine.best}',
                  color: Twenty48Colors.best,
                  centered: true,
                ),
                GameStat(
                  label: l10n.twenty48Moves,
                  value: '${_engine.moves}',
                  centered: true,
                ),
                GameStat(
                  label: l10n.twenty48Highest,
                  value: '${_engine.highestValue}',
                  color: Twenty48Colors.score,
                  centered: true,
                ),
              ],
              actions: [
                GameHudAction(
                  icon: Icons.undo_rounded,
                  tooltip: l10n.twenty48Undo,
                  onPressed: _engine.canUndo ? _undo : null,
                ),
                GameHudAction(
                  icon: Icons.restart_alt_rounded,
                  tooltip: l10n.twenty48NewGame,
                  onPressed: _newGame,
                ),
                GameHudAction(
                  icon: Icons.settings_outlined,
                  tooltip: l10n.commonSettings,
                  onPressed: () => Twenty48SettingsSheet.show(context),
                ),
              ],
            );

            final board = Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 500,
                    maxHeight: 500,
                  ),
                  child: Stack(
                    children: [
                      Twenty48Board(engine: _engine),
                      Positioned.fill(
                        child: _Overlay(
                          engine: _engine,
                          winDismissed: _winDismissed,
                          onKeepPlaying: () =>
                              setState(() => _winDismissed = true),
                          onNewGame: _newGame,
                          onUndo: _undo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (constraints.canSplit) {
              return Row(
                children: [
                  Expanded(
                    child: Twenty48DirectionalInput(
                      onDirection: _move,
                      child: board,
                    ),
                  ),
                  SizedBox(
                    width: math.min(220, constraints.maxWidth * 0.28),
                    child: hud,
                  ),
                ],
              );
            }
            return Column(
              children: [
                hud,
                Expanded(
                  child: Twenty48DirectionalInput(
                    onDirection: _move,
                    child: board,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The win announcement and the dead-end panel, or nothing at all.
class _Overlay extends StatelessWidget {
  final Twenty48Engine engine;
  final bool winDismissed;
  final VoidCallback onKeepPlaying;
  final VoidCallback onNewGame;
  final VoidCallback onUndo;

  const _Overlay({
    required this.engine,
    required this.winDismissed,
    required this.onKeepPlaying,
    required this.onNewGame,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (engine.isStuck) {
      return GameResultOverlay(
        title: l10n.twenty48NoMovesLeft,
        headline: '${engine.score}',
        headlineColor: Twenty48Colors.score,
        subtitle: engine.score >= engine.best && engine.score > 0
            ? l10n.twenty48NewBest
            : l10n.twenty48BestScore(engine.best),
        footnote: l10n.twenty48ReachedTile(engine.highestValue),
        scrimColor: Twenty48Colors.board,
        actions: [
          GameResultAction(
            label: l10n.twenty48NewGame,
            icon: Icons.restart_alt_rounded,
            onPressed: onNewGame,
          ),
          if (engine.canUndo)
            GameResultAction(
              label: l10n.twenty48Undo,
              icon: Icons.undo_rounded,
              onPressed: onUndo,
            ),
        ],
      );
    }

    if (engine.won && !winDismissed) {
      return GameResultOverlay(
        title: l10n.twenty48YouWin,
        headline: '2048',
        headlineColor: Twenty48Colors.forValue(2048),
        subtitle: l10n.twenty48WinSubtitle(engine.score),
        scrimColor: Twenty48Colors.board,
        actions: [
          GameResultAction(
            label: l10n.twenty48KeepPlaying,
            icon: Icons.play_arrow_rounded,
            onPressed: onKeepPlaying,
          ),
          GameResultAction(
            label: l10n.twenty48NewGame,
            icon: Icons.restart_alt_rounded,
            onPressed: onNewGame,
          ),
        ],
      );
    }

    return const IgnorePointer(child: SizedBox.shrink());
  }
}
