import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../audio/tone_generator.dart';

class SfWaveformSelector extends StatelessWidget {
  final ToneWaveform selected;
  final ValueChanged<ToneWaveform> onChanged;

  const SfWaveformSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String labelFor(ToneWaveform w) => switch (w) {
      ToneWaveform.sine => l10n.sfWaveSine,
      ToneWaveform.square => l10n.sfWaveSquare,
      ToneWaveform.triangle => l10n.sfWaveTriangle,
      ToneWaveform.sawtooth => l10n.sfWaveSawtooth,
    };
    IconData iconFor(ToneWaveform w) => switch (w) {
      ToneWaveform.sine => Icons.waves_outlined,
      ToneWaveform.square => Icons.square_outlined,
      ToneWaveform.triangle => Icons.change_history_outlined,
      ToneWaveform.sawtooth => Icons.show_chart_outlined,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ToneWaveform.values.map((w) {
        return ToolChip(
          icon: iconFor(w),
          label: labelFor(w),
          selected: selected == w,
          onTap: () => onChanged(w),
        );
      }).toList(),
    );
  }
}
