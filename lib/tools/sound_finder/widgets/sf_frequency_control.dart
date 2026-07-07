import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../sf_format.dart';

/// Logarithmic frequency picker: a big readout, a log-scaled slider, fine/coarse
/// steppers and quick presets. Shared by the generator and counter views.
class SfFrequencyControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final Color accent;

  static const double _minHz = 20;
  static const double _maxHz = 20000;
  static const List<double> _presets = [50, 60, 100, 440, 1000, 5000, 10000];

  const SfFrequencyControl({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  double get _logValue => math.log(value.clamp(_minHz, _maxHz)) / math.ln10;
  static double get _logMin => math.log(_minHz) / math.ln10;
  static double get _logMax => math.log(_maxHz) / math.ln10;

  void _step(double delta) => onChanged((value + delta).clamp(_minHz, _maxHz));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            formatHz(value),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Slider(
          value: _logValue,
          min: _logMin,
          max: _logMax,
          onChanged: (v) => onChanged(math.pow(10, v).toDouble()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepButton(label: '-10', onTap: () => _step(-10)),
            _StepButton(label: '-1', onTap: () => _step(-1)),
            const SizedBox(width: 8),
            _StepButton(label: '+1', onTap: () => _step(1)),
            _StepButton(label: '+10', onTap: () => _step(10)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _presets.map((p) {
            return ToolChip(
              label: formatHz(p),
              selected: (value - p).abs() < 0.5,
              onTap: () => onChanged(p),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StepButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label),
      ),
    );
  }
}
