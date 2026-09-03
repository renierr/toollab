import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../voice_distorter_state.dart';
import 'vd_record_button.dart';
import 'vd_save_clip_button.dart';

class VdTransportBar extends StatelessWidget {
  const VdTransportBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<VoiceDistorterState>();

    if (!state.hasClip || state.isRecording) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: state.isExporting
              ? null
              : state.isPlaying
              ? () => context.read<VoiceDistorterState>().stopPlayback()
              : () => context.read<VoiceDistorterState>().playCurrent(),
          icon: Icon(state.isPlaying ? Icons.stop : Icons.play_arrow),
          label: Text(
            state.isPlaying ? l10n.voiceDistorterStop : l10n.voiceDistorterPlay,
          ),
        ),
        // Live mode re-records via press-and-hold on the record button above;
        // a plain tap here would start a recording with no easy way to stop it.
        if (state.mode == VoiceDistorterMode.clip)
          OutlinedButton.icon(
            onPressed: state.isExporting
                ? null
                : () => startRecordingWithFeedback(context),
            icon: const Icon(Icons.mic_none_outlined),
            label: Text(l10n.voiceDistorterReRecord),
          ),
        const VdSaveClipButton(),
      ],
    );
  }
}
