import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

import '../signature_models.dart';
import '../signatures_state.dart';

/// Quick controls: pen width, color preset and curve mode.
class SignatureControls extends StatelessWidget {
  const SignatureControls({super.key});

  static const List<String> _presetColors = [
    '#0B3D91',
    '#111111',
    '#1565C0',
    '#C62828',
    '#2E7D32',
  ];

  static const Map<CurveMode, String> _curveLabels = {
    CurveMode.natural: 'Natural',
    CurveMode.fast: 'Fast',
    CurveMode.draft: 'Draft',
    CurveMode.none: 'Raw',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<SignaturesState>();
    final settings = state.settings;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.line_weight,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 12,
                  divisions: 11,
                  label: settings.penWidth.toStringAsFixed(0),
                  value: settings.penWidth.clamp(1, 12),
                  onChanged: (v) => context
                      .read<SignaturesState>()
                      .updateSettings(settings.copyWith(penWidth: v)),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  settings.penWidth.toStringAsFixed(0),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final hex in _presetColors)
                _ColorSwatch(
                  hex: hex,
                  selected:
                      settings.penColor.toUpperCase() == hex.toUpperCase(),
                  onTap: () => context.read<SignaturesState>().updateSettings(
                    settings.copyWith(penColor: hex),
                  ),
                ),
              Container(width: 1, height: 24, color: theme.dividerColor),
              for (final entry in _curveLabels.entries)
                ToolChip(
                  label: entry.value,
                  selected: settings.curveMode == entry.key,
                  onTap: () => context.read<SignaturesState>().updateSettings(
                    settings.copyWith(curveMode: entry.key),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: colorFromHex(hex),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.4),
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
