import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/tool_chip.dart';
import '../voice_distorter_state.dart';

class VdModeSwitch extends StatelessWidget {
  const VdModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<VoiceDistorterState>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ToolChip(
          icon: Icons.content_cut,
          label: l10n.voiceDistorterModeClip,
          selected: state.mode == VoiceDistorterMode.clip,
          onTap: () => context.read<VoiceDistorterState>().setMode(
            VoiceDistorterMode.clip,
          ),
        ),
        const SizedBox(width: 8),
        ToolChip(
          icon: Icons.bolt_outlined,
          label: l10n.voiceDistorterModeLive,
          selected: state.mode == VoiceDistorterMode.live,
          onTap: () => context.read<VoiceDistorterState>().setMode(
            VoiceDistorterMode.live,
          ),
        ),
      ],
    );
  }
}
