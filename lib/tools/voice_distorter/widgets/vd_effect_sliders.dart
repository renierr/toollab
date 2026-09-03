import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../engine/voice_effect.dart';
import '../voice_distorter_state.dart';
import 'vd_save_preset_dialog.dart';

class VdEffectSliders extends StatelessWidget {
  const VdEffectSliders({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<VoiceDistorterState>();
    final VoiceEffectParams p = state.params;

    void update(VoiceEffectParams next) =>
        context.read<VoiceDistorterState>().updateParams(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.voiceDistorterCustomTitle,
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showSavePresetDialog(context),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(l10n.voiceDistorterSaveAsPreset),
            ),
          ],
        ),
        _KnobSlider(
          label: l10n.voiceDistorterPitch,
          value: p.pitchSemitones,
          min: -24,
          max: 24,
          valueLabel:
              '${p.pitchSemitones >= 0 ? '+' : ''}${p.pitchSemitones.round()}',
          onChanged: (v) => update(p.copyWith(pitchSemitones: v)),
        ),
        _KnobSlider(
          label: l10n.voiceDistorterRobot,
          value: p.robotAmount,
          min: 0,
          max: 1,
          valueLabel: '${(p.robotAmount * 100).round()}%',
          onChanged: (v) => update(p.copyWith(robotAmount: v)),
        ),
        _KnobSlider(
          label: l10n.voiceDistorterEcho,
          value: p.echoAmount,
          min: 0,
          max: 1,
          valueLabel: '${(p.echoAmount * 100).round()}%',
          onChanged: (v) => update(p.copyWith(echoAmount: v)),
        ),
        _KnobSlider(
          label: l10n.voiceDistorterReverb,
          value: p.reverbAmount,
          min: 0,
          max: 1,
          valueLabel: '${(p.reverbAmount * 100).round()}%',
          onChanged: (v) => update(p.copyWith(reverbAmount: v)),
        ),
        _KnobSlider(
          label: l10n.voiceDistorterLofi,
          value: p.lofiAmount,
          min: 0,
          max: 1,
          valueLabel: '${(p.lofiAmount * 100).round()}%',
          onChanged: (v) => update(p.copyWith(lofiAmount: v)),
        ),
        _KnobSlider(
          label: l10n.voiceDistorterDistortion,
          value: p.distortionAmount,
          min: 0,
          max: 1,
          valueLabel: '${(p.distortionAmount * 100).round()}%',
          onChanged: (v) => update(p.copyWith(distortionAmount: v)),
        ),
      ],
    );
  }
}

class _KnobSlider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _KnobSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
