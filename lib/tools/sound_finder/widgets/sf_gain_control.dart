import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../sound_finder_state.dart';
import 'sf_labeled_slider.dart';

/// Software mic-gain boost for the live analysis modes. Multiplies the raw PCM
/// before FFT/loudness, letting the user pull up faint sounds that the
/// (intentionally un-processed) hardware capture leaves quiet.
class SfGainControl extends StatelessWidget {
  const SfGainControl({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SoundFinderState>();

    if (state.micStatus != MicStatus.running) return const SizedBox.shrink();

    return SfLabeledSlider(
      icon: Icons.volume_up_outlined,
      label: l10n.sfMicGain,
      valueText: '×${state.micGain.toStringAsFixed(1)}',
      value: state.micGain,
      min: 1,
      max: SoundFinderState.maxMicGain,
      divisions: ((SoundFinderState.maxMicGain - 1) * 2).round(),
      onChanged: (v) => context.read<SoundFinderState>().setMicGain(v),
    );
  }
}
