import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/theme/theme.dart';
import 'package:tool_lab/widgets/info_card.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../sf_format.dart';
import '../sound_finder_colors.dart';
import '../sound_finder_state.dart';
import 'sf_frequency_control.dart';
import 'sf_labeled_slider.dart';
import 'sf_readout.dart';
import 'sf_spectrum_panel.dart';
import 'sf_waveform_selector.dart';

class SfCounterView extends StatelessWidget {
  const SfCounterView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SoundFinderState>();
    final theme = Theme.of(context);
    final bool playing = state.counterPlaying;
    final bool micOn = state.micStatus == MicStatus.running;
    final bool inverted = (state.counterPhaseDeg - 180).abs() < 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          icon: Icons.info_outline,
          title: l10n.sfCounterTitle,
          titleColor: AppTheme.statusAmber,
          child: Text(
            l10n.sfCounterDisclaimer,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        if (micOn)
          InfoCard(
            icon: Icons.graphic_eq_outlined,
            title: l10n.sfDetected,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SfReadout(
                      label: l10n.sfDominant,
                      value: formatHz(state.smoothPeakHz),
                      valueColor: SoundFinderColors.spectrumHigh,
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context
                          .read<SoundFinderState>()
                          .useDetectedFrequency(),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(l10n.sfUseDetected),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SfSpectrumPanel(),
              ],
            ),
          )
        else
          Text(
            l10n.sfCounterMicOff,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.settings_input_component_outlined,
          title: l10n.sfTargetFrequency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SfFrequencyControl(
                value: state.counterFreq,
                accent: SoundFinderColors.spectrumHigh,
                onChanged: (v) =>
                    context.read<SoundFinderState>().setCounterFreq(v),
              ),
              const SizedBox(height: 12),
              Text(l10n.sfWaveform, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SfWaveformSelector(
                selected: state.counterWave,
                onChanged: (w) =>
                    context.read<SoundFinderState>().setCounterWave(w),
              ),
              const SizedBox(height: 12),
              SfLabeledSlider(
                icon: Icons.rotate_left_outlined,
                label: l10n.sfPhase,
                valueText: '${state.counterPhaseDeg.round()}°',
                value: state.counterPhaseDeg,
                max: 360,
                divisions: 72,
                onChanged: (v) =>
                    context.read<SoundFinderState>().setCounterPhaseDeg(v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: ToolChip(
                  icon: Icons.flip_outlined,
                  label: l10n.sfInvertPhase,
                  selected: inverted,
                  onTap: () => context
                      .read<SoundFinderState>()
                      .setCounterPhaseDeg(inverted ? 0 : 180),
                ),
              ),
              const SizedBox(height: 8),
              SfLabeledSlider(
                icon: Icons.blur_on_outlined,
                label: l10n.sfMaskNoise,
                valueText: '${(state.counterNoise * 100).round()}%',
                value: state.counterNoise,
                onChanged: (v) =>
                    context.read<SoundFinderState>().setCounterNoise(v),
              ),
              const SizedBox(height: 8),
              SfLabeledSlider(
                icon: Icons.volume_up_outlined,
                label: l10n.sfVolume,
                valueText: '${(state.counterVol * 100).round()}%',
                value: state.counterVol,
                onChanged: (v) =>
                    context.read<SoundFinderState>().setCounterVol(v),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () =>
                    context.read<SoundFinderState>().toggleCounter(),
                icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                label: Text(playing ? l10n.sfStop : l10n.sfPlayCounter),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: playing ? AppTheme.statusRed : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
