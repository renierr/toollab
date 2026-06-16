import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import '../signature_models.dart';
import '../signatures_state.dart';

/// Advanced capture/render tuning, shown inside the end drawer.
class SignatureAdvancedPanel extends StatelessWidget {
  const SignatureAdvancedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<SignaturesState>();
    final s = state.settings;
    final read = context.read<SignaturesState>();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(l10n.sigAdvanced, style: theme.textTheme.titleLarge),
                const Spacer(),
                TextButton.icon(
                  onPressed: read.resetSettings,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(l10n.commonReset),
                ),
              ],
            ),
            const Divider(),
            _Dropdown<RdpMode>(
              label: l10n.sigReduceLines,
              value: s.rdpMode,
              values: RdpMode.values,
              nameOf: (m) => m.name,
              onChanged: (m) => read.updateSettings(s.copyWith(rdpMode: m)),
            ),
            _SliderRow(
              label: l10n.sigMoveTolerance,
              value: s.moveTolerance,
              min: 0,
              max: 20,
              onChanged: (v) =>
                  read.updateSettings(s.copyWith(moveTolerance: v)),
            ),
            _SliderRow(
              label: l10n.sigMinWidthFactor,
              value: s.minWidthFactor,
              min: 0.05,
              max: 1.0,
              onChanged: (v) =>
                  read.updateSettings(s.copyWith(minWidthFactor: v)),
            ),
            _SliderRow(
              label: l10n.sigMaxWidthFactor,
              value: s.maxWidthFactor,
              min: 1.0,
              max: 3.0,
              onChanged: (v) =>
                  read.updateSettings(s.copyWith(maxWidthFactor: v)),
            ),
            _SliderRow(
              label: l10n.sigVelocitySensitivity,
              value: s.velocitySensitivity,
              min: 0,
              max: 2.0,
              onChanged: (v) =>
                  read.updateSettings(s.copyWith(velocitySensitivity: v)),
            ),
            _SliderRow(
              label: l10n.sigVelocityInfluence,
              value: s.velocityInfluence,
              min: 0,
              max: 1.0,
              onChanged: (v) =>
                  read.updateSettings(s.copyWith(velocityInfluence: v)),
            ),
            _SliderRow(
              label: l10n.sigPressureInfluence,
              value: s.pressureInfluence,
              min: 0,
              max: 1.0,
              onChanged: (v) =>
                  read.updateSettings(s.copyWith(pressureInfluence: v)),
            ),
            _SliderRow(
              label: l10n.sigWidthSmoothing,
              value: s.widthSmoothing,
              min: 0,
              max: 1.0,
              onChanged: (v) =>
                  read.updateSettings(s.copyWith(widthSmoothing: v)),
            ),
            _SliderRow(
              label: l10n.sigExportDpi,
              value: s.dpi.toDouble(),
              min: 72,
              max: 600,
              divisions: 44,
              decimals: 0,
              onChanged: (v) => read.updateSettings(s.copyWith(dpi: v.round())),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.decimals = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
            Text(
              clamped.toStringAsFixed(decimals),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          min: min,
          max: max,
          divisions: divisions,
          value: clamped,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) nameOf;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.nameOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
          DropdownButton<T>(
            value: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            items: [
              for (final v in values)
                DropdownMenuItem<T>(value: v, child: Text(nameOf(v))),
            ],
          ),
        ],
      ),
    );
  }
}
