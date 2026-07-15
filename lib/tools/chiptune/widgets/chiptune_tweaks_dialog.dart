import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/widgets/responsive_alert_dialog.dart';

import '../chiptune_colors.dart';
import '../engine/mixer.dart';

class ChiptuneTweaksDialog extends StatefulWidget {
  final ChiptuneInterpolation interpolation;
  final double stereoWidth;
  final double preAmp;
  final ChiptuneAmigaFilter amigaFilter;
  final double rampStep;
  final double modSeparation;
  final ValueChanged<ChiptuneInterpolation> onInterpolationChanged;
  final ValueChanged<double> onStereoWidthChanged;
  final ValueChanged<double> onPreAmpChanged;
  final ValueChanged<ChiptuneAmigaFilter> onAmigaFilterChanged;
  final ValueChanged<double> onRampStepChanged;
  final ValueChanged<double> onModSeparationChanged;

  const ChiptuneTweaksDialog({
    super.key,
    required this.interpolation,
    required this.stereoWidth,
    required this.preAmp,
    required this.amigaFilter,
    required this.rampStep,
    required this.modSeparation,
    required this.onInterpolationChanged,
    required this.onStereoWidthChanged,
    required this.onPreAmpChanged,
    required this.onAmigaFilterChanged,
    required this.onRampStepChanged,
    required this.onModSeparationChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required ChiptuneInterpolation interpolation,
    required double stereoWidth,
    required double preAmp,
    required ChiptuneAmigaFilter amigaFilter,
    required double rampStep,
    required double modSeparation,
    required ValueChanged<ChiptuneInterpolation> onInterpolationChanged,
    required ValueChanged<double> onStereoWidthChanged,
    required ValueChanged<double> onPreAmpChanged,
    required ValueChanged<ChiptuneAmigaFilter> onAmigaFilterChanged,
    required ValueChanged<double> onRampStepChanged,
    required ValueChanged<double> onModSeparationChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ChiptuneTweaksDialog(
        interpolation: interpolation,
        stereoWidth: stereoWidth,
        preAmp: preAmp,
        amigaFilter: amigaFilter,
        rampStep: rampStep,
        modSeparation: modSeparation,
        onInterpolationChanged: onInterpolationChanged,
        onStereoWidthChanged: onStereoWidthChanged,
        onPreAmpChanged: onPreAmpChanged,
        onAmigaFilterChanged: onAmigaFilterChanged,
        onRampStepChanged: onRampStepChanged,
        onModSeparationChanged: onModSeparationChanged,
      ),
    );
  }

  @override
  State<ChiptuneTweaksDialog> createState() => _ChiptuneTweaksDialogState();
}

class _ChiptuneTweaksDialogState extends State<ChiptuneTweaksDialog> {
  static const double _rampOff = 1.0;
  static const double _rampFast = 1.0 / 16.0;
  static const double _rampSmooth = 1.0 / 48.0;

  late ChiptuneInterpolation _interpolation = widget.interpolation;
  late double _stereoWidth = widget.stereoWidth;
  late double _preAmp = widget.preAmp;
  late ChiptuneAmigaFilter _amigaFilter = widget.amigaFilter;
  late double _rampStep = widget.rampStep;
  late double _modSeparation = widget.modSeparation;

  double _nearestRamp(double v) {
    double best = _rampFast;
    double bestDist = (v - best).abs();
    for (final p in const [_rampOff, _rampFast, _rampSmooth]) {
      final d = (v - p).abs();
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final interpOptions = <ChiptuneInterpolation, String>{
      ChiptuneInterpolation.sinc: l10n.chipInterpolationSinc,
      ChiptuneInterpolation.cubic: l10n.chipInterpolationCubic,
      ChiptuneInterpolation.linear: l10n.chipInterpolationLinear,
      ChiptuneInterpolation.none: l10n.chipInterpolationNone,
    };

    return ResponsiveAlertDialog(
      title: Text(l10n.chipTweaks),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.chipInterpolation, style: labelStyle),
              const SizedBox(height: 4),
              ...interpOptions.entries.map((entry) {
                final isSelected = _interpolation == entry.key;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : null,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  onTap: () {
                    setState(() => _interpolation = entry.key);
                    widget.onInterpolationChanged(entry.key);
                  },
                );
              }),
              const Divider(height: 24),
              Text(l10n.chipPreAmp, style: labelStyle),
              _SliderRow(
                value: _preAmp,
                min: 0.0,
                max: 2.0,
                label: '${(_preAmp * 100).round()}%',
                onChanged: (v) {
                  setState(() => _preAmp = v);
                  widget.onPreAmpChanged(v);
                },
              ),
              const Divider(height: 24),
              Text(l10n.chipAmigaFilter, style: labelStyle),
              const SizedBox(height: 8),
              SegmentedButton<ChiptuneAmigaFilter>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ChiptuneAmigaFilter.auto,
                    label: Text(l10n.chipAmigaFilterAuto),
                  ),
                  ButtonSegment(
                    value: ChiptuneAmigaFilter.on,
                    label: Text(l10n.chipAmigaFilterOn),
                  ),
                  ButtonSegment(
                    value: ChiptuneAmigaFilter.off,
                    label: Text(l10n.chipAmigaFilterOff),
                  ),
                ],
                selected: {_amigaFilter},
                onSelectionChanged: (set) {
                  final mode = set.first;
                  setState(() => _amigaFilter = mode);
                  widget.onAmigaFilterChanged(mode);
                },
              ),
              const Divider(height: 24),
              Text(l10n.chipVolumeRamping, style: labelStyle),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: _rampOff, label: Text(l10n.chipRampOff)),
                  ButtonSegment(
                    value: _rampFast,
                    label: Text(l10n.chipRampFast),
                  ),
                  ButtonSegment(
                    value: _rampSmooth,
                    label: Text(l10n.chipRampSmooth),
                  ),
                ],
                selected: {_nearestRamp(_rampStep)},
                onSelectionChanged: (set) {
                  final v = set.first;
                  setState(() => _rampStep = v);
                  widget.onRampStepChanged(v);
                },
              ),
              const Divider(height: 24),
              Text(l10n.chipStereoSeparation, style: labelStyle),
              _SliderRow(
                value: _modSeparation,
                min: 0.0,
                max: 1.0,
                label: '${(_modSeparation * 100).round()}%',
                onChanged: (v) {
                  setState(() => _modSeparation = v);
                  widget.onModSeparationChanged(v);
                },
              ),
              const Divider(height: 24),
              Text(l10n.chipStereoWidth, style: labelStyle),
              _SliderRow(
                value: _stereoWidth,
                min: 0.0,
                max: 1.0,
                label: '${(_stereoWidth * 100).round()}%',
                onChanged: (v) {
                  setState(() => _stereoWidth = v);
                  widget.onStereoWidthChanged(v);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonBack),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: ChiptuneColors.accent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
