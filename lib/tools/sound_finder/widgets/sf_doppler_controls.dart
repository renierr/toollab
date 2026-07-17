import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'sf_labeled_slider.dart';

class SfDopplerControls extends StatelessWidget {
  final double fApproach;
  final double fRecede;
  final double t0;
  final double distance;
  final double temperature;
  final double duration;

  final ValueChanged<double> onFApproachChanged;
  final ValueChanged<double> onFRecedeChanged;
  final ValueChanged<double> onT0Changed;
  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<double> onTemperatureChanged;

  const SfDopplerControls({
    super.key,
    required this.fApproach,
    required this.fRecede,
    required this.t0,
    required this.distance,
    required this.temperature,
    required this.duration,
    required this.onFApproachChanged,
    required this.onFRecedeChanged,
    required this.onT0Changed,
    required this.onDistanceChanged,
    required this.onTemperatureChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final double maxT0 = duration > 0 ? duration : 5.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SfLabeledSlider(
              icon: Icons.arrow_upward_outlined,
              label: '${l10n.sfDopplerSourceFreq} (${l10n.sfGuidanceHotter})',
              valueText: '${fApproach.toStringAsFixed(0)} Hz',
              value: fApproach,
              min: 150.0,
              max: 2000.0,
              onChanged: onFApproachChanged,
            ),
            const SizedBox(height: 12),
            SfLabeledSlider(
              icon: Icons.arrow_downward_outlined,
              label: '${l10n.sfDopplerSourceFreq} (${l10n.sfGuidanceColder})',
              valueText: '${fRecede.toStringAsFixed(0)} Hz',
              value: fRecede,
              min: 150.0,
              max: 2000.0,
              onChanged: onFRecedeChanged,
            ),
            const SizedBox(height: 12),
            SfLabeledSlider(
              icon: Icons.access_time_outlined,
              label: l10n.sfDopplerInflection,
              valueText: '${t0.toStringAsFixed(2)} s',
              value: t0,
              min: 0.0,
              max: maxT0,
              onChanged: onT0Changed,
            ),
            const SizedBox(height: 12),
            SfLabeledSlider(
              icon: Icons.straighten_outlined,
              label: l10n.sfDopplerDistance,
              valueText: '${distance.toStringAsFixed(1)} m',
              value: distance,
              min: 0.5,
              max: 30.0,
              onChanged: onDistanceChanged,
            ),
            const SizedBox(height: 12),
            SfLabeledSlider(
              icon: Icons.thermostat_outlined,
              label: l10n.sfDopplerTemp,
              valueText: '${temperature.toStringAsFixed(1)} °C',
              value: temperature,
              min: -10.0,
              max: 40.0,
              onChanged: onTemperatureChanged,
            ),
          ],
        ),
      ),
    );
  }
}
