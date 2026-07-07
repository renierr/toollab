import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/info_card.dart';

import '../sound_finder_state.dart';
import 'sf_frequency_control.dart';
import 'sf_labeled_slider.dart';
import 'sf_waveform_selector.dart';

class SfGeneratorView extends StatelessWidget {
  const SfGeneratorView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SoundFinderState>();
    final bool playing = state.generatorPlaying;

    return InfoCard(
      icon: Icons.tune_outlined,
      title: l10n.sfGeneratorTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.sfGeneratorHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SfFrequencyControl(
            value: state.genFreq,
            accent: AppTheme.accentPurple,
            onChanged: (v) => context.read<SoundFinderState>().setGenFreq(v),
          ),
          const SizedBox(height: 12),
          Text(l10n.sfWaveform, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SfWaveformSelector(
            selected: state.genWave,
            onChanged: (w) => context.read<SoundFinderState>().setGenWave(w),
          ),
          const SizedBox(height: 12),
          SfLabeledSlider(
            icon: Icons.volume_up_outlined,
            label: l10n.sfVolume,
            valueText: '${(state.genVol * 100).round()}%',
            value: state.genVol,
            onChanged: (v) => context.read<SoundFinderState>().setGenVol(v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.read<SoundFinderState>().toggleGenerator(),
            icon: Icon(playing ? Icons.stop : Icons.play_arrow),
            label: Text(playing ? l10n.sfStop : l10n.sfPlayTone),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: playing ? AppTheme.statusRed : null,
            ),
          ),
        ],
      ),
    );
  }
}
