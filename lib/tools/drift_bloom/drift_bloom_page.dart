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
import 'drift_bloom_audio_service.dart';
import 'drift_bloom_colors.dart';
import 'drift_bloom_state.dart';
import 'engine/drift_bloom_audio.dart';
import 'engine/drift_bloom_engine.dart';
import 'widgets/drift_bloom_board.dart';
import 'widgets/drift_bloom_settings_sheet.dart';

class DriftBloomPage extends StatefulWidget {
  const DriftBloomPage({super.key});

  @override
  State<DriftBloomPage> createState() => _DriftBloomPageState();
}

class _DriftBloomPageState extends State<DriftBloomPage>
    with DisposeCleanup, WidgetsBindingObserver {
  final DriftBloomEngine _engine = DriftBloomEngine();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    onDispose(_engine.dispose);
    onDispose(DriftBloomAudioService.instance.stopLoop);
    onDispose(() => unawaited(DriftBloomAudioService.instance.releaseAll()));
    unawaited(_bootstrap());
  }

  bool _isActive = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isActive = state == AppLifecycleState.resumed;
  }

  Future<void> _bootstrap() async {
    final settings = context.read<DriftBloomState>();
    await settings.restore();
    if (!mounted) return;
    _engine.setBest(settings.best);
    _engine.setEasyModeResolver(() => context.read<DriftBloomState>().easyMode);
    _engine.setRingLifeResolver(() => context.read<DriftBloomState>().ringLife);
    await DriftBloomSfx.load();
    DriftBloomAudioService.instance.playLoop(DriftBloomSfx.padLoop);
    _engine.onBest = (best) {
      if (!mounted) return;
      unawaited(context.read<DriftBloomState>().saveBest(best));
    };
  }

  void _onBloom(bool golden) {
    final settings = context.read<DriftBloomState>();
    if (settings.hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    DriftBloomAudioService.instance.play(
      golden ? DriftBloomSfx.goldenBloom : DriftBloomSfx.bloom(_engine.combo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<DriftBloomState>();
    DriftBloomAudioService.instance.setMasterVolume(
      settings.soundEnabled ? 1 : 0,
    );
    return ToolLayout(
      title: DriftBloomTool.config.localizedName(l10n),
      backgroundColor: DriftBloomColors.page,
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
                  label: l10n.driftBloomScore,
                  value: '${_engine.score}',
                  color: DriftBloomColors.score,
                  centered: true,
                ),
                GameStat(
                  label: l10n.driftBloomBest,
                  value: '${_engine.best}',
                  color: DriftBloomColors.best,
                  centered: true,
                ),
                GameStat(
                  label: l10n.driftBloomPetals,
                  value: '${_engine.petals}',
                  centered: true,
                ),
              ],
              actions: [
                GameHudAction(
                  icon: Icons.restart_alt_rounded,
                  tooltip: l10n.driftBloomNewGame,
                  onPressed: _engine.newGame,
                ),
                GameHudAction(
                  icon: Icons.settings_outlined,
                  tooltip: l10n.commonSettings,
                  onPressed: () => DriftBloomSettingsSheet.show(context),
                ),
              ],
            );
            final board = Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox.expand(
                child: DriftBloomBoard(
                  engine: _engine,
                  isActive: _isActive,
                  onBloom: _onBloom,
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
