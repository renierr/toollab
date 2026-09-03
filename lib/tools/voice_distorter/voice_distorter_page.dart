import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/tool_page_state.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/tool_layout.dart';
import 'config.dart';
import 'voice_distorter_state.dart';
import 'widgets/vd_effect_sliders.dart';
import 'widgets/vd_mode_switch.dart';
import 'widgets/vd_preset_grid.dart';
import 'widgets/vd_record_button.dart';
import 'widgets/vd_transport_bar.dart';

class VoiceDistorterPage extends StatefulWidget {
  const VoiceDistorterPage({super.key});

  @override
  State<VoiceDistorterPage> createState() => _VoiceDistorterPageState();
}

class _VoiceDistorterPageState extends State<VoiceDistorterPage>
    with DisposeCleanup<VoiceDistorterPage> {
  @override
  void initState() {
    super.initState();
    // The state provider is app-scoped, so leaving the page must silence it.
    final state = context.read<VoiceDistorterState>();
    onDispose(() {
      unawaited(state.stopRecording());
      unawaited(state.stopPlayback());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<VoiceDistorterState>();

    return ToolLayout(
      title: VoiceDistorterTool.config.localizedName(l10n),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: VdModeSwitch()),
                const SizedBox(height: 20),
                const Center(child: VdRecordButton()),
                const SizedBox(height: 16),
                const Center(child: VdTransportBar()),
                if (!state.hasClip) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      l10n.voiceDistorterNoClipHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.voiceDistorterPresetsTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                const VdPresetGrid(),
                const SizedBox(height: 24),
                const VdEffectSliders(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
