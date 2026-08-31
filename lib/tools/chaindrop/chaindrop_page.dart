import 'dart:async';

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
import 'chaindrop_audio_service.dart';
import 'chaindrop_colors.dart';
import 'chaindrop_state.dart';
import 'config.dart';
import 'engine/chaindrop_audio.dart';
import 'engine/chaindrop_engine.dart';
import 'widgets/chaindrop_board.dart';
import 'widgets/chaindrop_power_menu_sheet.dart';
import 'widgets/chaindrop_queue_bar.dart';
import 'widgets/chaindrop_settings_sheet.dart';

/// Chain Drop's entry point: owns the engine, wires its sound/haptics
/// callback, and composes the queue, board, HUD and game-over overlay.
class ChainDropPage extends StatefulWidget {
  const ChainDropPage({super.key});

  @override
  State<ChainDropPage> createState() => _ChainDropPageState();
}

class _ChainDropPageState extends State<ChainDropPage> with DisposeCleanup {
  final ChainDropEngine _engine = ChainDropEngine();

  @override
  void initState() {
    super.initState();
    onDispose(_engine.dispose);
    onDispose(() => unawaited(ChainDropAudioService.instance.releaseAll()));
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await context.read<ChainDropState>().restore();
    await ChainDropSfx.load();
    if (!mounted) return;
    _engine.onSfx = _handleSfx;
    await _engine.start();
  }

  void _handleSfx(String key) {
    ChainDropAudioService.instance.play(key);
    if (!mounted || !context.read<ChainDropState>().hapticsEnabled) return;
    switch (key) {
      case ChainDropSfxKeys.pop:
        HapticFeedback.selectionClick();
      case ChainDropSfxKeys.crackBreak:
      case ChainDropSfxKeys.crackWave:
        HapticFeedback.mediumImpact();
      case ChainDropSfxKeys.gameOver:
        HapticFeedback.heavyImpact();
    }
  }

  void _drop(int column) => unawaited(_engine.dropDisc(column));

  void _newGame() => _engine.newGame();

  void _undo() => _engine.undoMove();

  Future<void> _openPowerMenu() async {
    final power = await ChainDropPowerMenuSheet.show(context);
    if (power != null) unawaited(_engine.usePower(power));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ChainDropState>();
    ChainDropAudioService.instance.setMasterVolume(state.soundEnabled ? 1 : 0);

    return ToolLayout(
      title: ChainDropTool.config.localizedName(l10n),
      backgroundColor: ChainDropColors.page,
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
                  label: l10n.chaindropScore,
                  value: '${_engine.score}',
                  centered: true,
                ),
                GameStat(
                  label: l10n.chaindropBest,
                  value: '${_engine.best}',
                  color: ChainDropColors.best,
                  centered: true,
                ),
                GameStat(
                  label: l10n.chaindropLevel,
                  value: '${_engine.level}',
                  color: ChainDropColors.score,
                  centered: true,
                ),
              ],
              actions: [
                GameHudAction(
                  icon: Icons.undo_rounded,
                  tooltip: l10n.chaindropUndo,
                  onPressed: _engine.canUndo ? _undo : null,
                ),
                GameHudAction(
                  icon: Icons.auto_awesome,
                  tooltip: l10n.chaindropPowerMenu,
                  onPressed: _engine.isResolving || _engine.isGameOver
                      ? null
                      : _openPowerMenu,
                ),
                GameHudAction(
                  icon: Icons.restart_alt_rounded,
                  tooltip: l10n.chaindropNewGame,
                  onPressed: _newGame,
                ),
                GameHudAction(
                  icon: Icons.settings_outlined,
                  tooltip: l10n.commonSettings,
                  onPressed: () => ChainDropSettingsSheet.show(context),
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
                    maxHeight: 560,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChainDropQueueBar(queue: _engine.queue),
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          ChainDropBoard(engine: _engine, onColumnTap: _drop),
                          Positioned.fill(
                            child: _Overlay(
                              engine: _engine,
                              onNewGame: _newGame,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );

            if (constraints.canSplit) {
              return Row(
                children: [
                  Expanded(child: board),
                  SizedBox(
                    width: (220 < constraints.maxWidth * 0.28)
                        ? 220
                        : constraints.maxWidth * 0.28,
                    child: hud,
                  ),
                ],
              );
            }
            return Column(
              children: [
                hud,
                Expanded(child: board),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The game-over panel, or nothing at all.
class _Overlay extends StatelessWidget {
  final ChainDropEngine engine;
  final VoidCallback onNewGame;

  const _Overlay({required this.engine, required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!engine.isGameOver) {
      return const IgnorePointer(child: SizedBox.shrink());
    }

    return GameResultOverlay(
      title: l10n.chaindropGameOver,
      headline: '${engine.score}',
      headlineColor: ChainDropColors.score,
      subtitle: engine.score >= engine.best && engine.score > 0
          ? l10n.chaindropNewBest
          : l10n.chaindropBestScore(engine.best),
      footnote: l10n.chaindropLevelReached(engine.level),
      scrimColor: ChainDropColors.board,
      actions: [
        GameResultAction(
          label: l10n.chaindropNewGame,
          icon: Icons.restart_alt_rounded,
          onPressed: onNewGame,
        ),
      ],
    );
  }
}
