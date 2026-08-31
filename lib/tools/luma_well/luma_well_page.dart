import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/game_hud.dart';
import 'package:tool_lab/widgets/game_stat.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'engine/luma_well_engine.dart';
import 'luma_well_colors.dart';
import 'luma_well_state.dart';
import 'widgets/luma_well_board.dart';
import 'widgets/luma_well_power_sheet.dart';
import 'widgets/luma_well_settings_sheet.dart';

class LumaWellPage extends StatefulWidget {
  const LumaWellPage({super.key});

  @override
  State<LumaWellPage> createState() => _LumaWellPageState();
}

class _LumaWellPageState extends State<LumaWellPage>
    with DisposeCleanup, WidgetsBindingObserver {
  final LumaWellEngine _engine = LumaWellEngine();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    onDispose(() async {
      await _engine.saveNow();
      _engine.dispose();
    });
    unawaited(_bootstrap());
  }

  bool _isActive = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isActive = state == AppLifecycleState.resumed;
  }

  Future<void> _bootstrap() async {
    await context.read<LumaWellState>().restore();
    if (!mounted) {
      return;
    }
    _engine.setEasyModeResolver(() => context.read<LumaWellState>().easyMode);
    _engine.setUnlimitedPowersResolver(
      () => context.read<LumaWellState>().unlimitedPowers,
    );
    await _engine.start();
  }

  void _onMerge(bool powerCollected) {
    if (context.read<LumaWellState>().hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (powerCollected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).lumaWellPowerOrbCollected),
        ),
      );
    }
  }

  Future<void> _openPowers() async {
    final power = await LumaWellPowerSheet.show(context);
    if (power != null) {
      _engine.usePower(power);
    }
  }

  Future<void> _confirmNewGame() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lumaWellNewGameConfirmTitle),
        content: Text(l10n.lumaWellNewGameConfirmText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.lumaWellNewGame),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _engine.newGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    context.watch<LumaWellState>();
    return ToolLayout(
      title: LumaWellTool.config.localizedName(l10n),
      backgroundColor: LumaWellColors.page,
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
                  label: l10n.lumaWellScore,
                  value: '${_engine.score}',
                  color: LumaWellColors.score,
                  centered: true,
                ),
                GameStat(
                  label: l10n.lumaWellBest,
                  value: '${_engine.best}',
                  color: LumaWellColors.best,
                  centered: true,
                ),
                GameStat(
                  label: l10n.lumaWellMerges,
                  value: '${_engine.merges}',
                  centered: true,
                ),
                GameStat(
                  label: l10n.lumaWellStage,
                  value: '${_engine.stage}',
                  centered: true,
                ),
              ],
              actions: [
                GameHudAction(
                  icon: Icons.auto_awesome_outlined,
                  tooltip: l10n.lumaWellPowerMenuCharges(_engine.powerCharges),
                  onPressed:
                      _engine.powerCharges == 0 &&
                          !context.read<LumaWellState>().unlimitedPowers
                      ? null
                      : _openPowers,
                ),
                GameHudAction(
                  icon: Icons.restart_alt_rounded,
                  tooltip: l10n.lumaWellNewGame,
                  onPressed: _confirmNewGame,
                ),
                GameHudAction(
                  icon: Icons.settings_outlined,
                  tooltip: l10n.commonSettings,
                  onPressed: () => LumaWellSettingsSheet.show(context),
                ),
              ],
            );
            final board = Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox.expand(
                child: LumaWellBoard(
                  engine: _engine,
                  isActive: _isActive,
                  onMerge: _onMerge,
                ),
              ),
            );
            return constraints.canSplit
                ? Row(
                    children: [
                      Expanded(child: board),
                      SizedBox(width: 220, child: hud),
                    ],
                  )
                : Column(
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
