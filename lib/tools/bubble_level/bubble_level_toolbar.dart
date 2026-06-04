import 'package:flutter/material.dart';

enum LevelMode { mode2d, mode1d }

class BubbleLevelToolbar extends StatelessWidget {
  final LevelMode mode;
  final double tolerance;
  final bool rulerVisible;
  final bool rotationLocked;
  final bool wakeLocked;
  final ValueChanged<LevelMode> onModeChanged;
  final ValueChanged<double> onToleranceChanged;
  final VoidCallback onToggleRuler;
  final VoidCallback onCalibrateRuler;
  final VoidCallback onSetZero;
  final VoidCallback onResetZero;
  final VoidCallback onToggleRotationLock;
  final VoidCallback onToggleWakeLock;

  const BubbleLevelToolbar({
    super.key,
    required this.mode,
    required this.tolerance,
    required this.rulerVisible,
    required this.rotationLocked,
    required this.wakeLocked,
    required this.onModeChanged,
    required this.onToleranceChanged,
    required this.onToggleRuler,
    required this.onCalibrateRuler,
    required this.onSetZero,
    required this.onResetZero,
    required this.onToggleRotationLock,
    required this.onToggleWakeLock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _ToolChip(
              label: '2-Axis',
              selected: mode == LevelMode.mode2d,
              onTap: () => onModeChanged(LevelMode.mode2d),
            ),
            _ToolChip(
              label: 'Beam',
              selected: mode == LevelMode.mode1d,
              onTap: () => onModeChanged(LevelMode.mode1d),
            ),
            _ToolChip(
              label: 'Ruler',
              selected: rulerVisible,
              onTap: onToggleRuler,
            ),
            if (rulerVisible)
              _ToolChip(
                label: 'Calibrate',
                selected: false,
                onTap: onCalibrateRuler,
              ),
            _ToolChip(
              label: rotationLocked ? 'Locked' : 'Lock Rot.',
              selected: rotationLocked,
              onTap: onToggleRotationLock,
            ),
            _ToolChip(label: 'Set Zero', selected: false, onTap: onSetZero),
            _ToolChip(label: 'Reset Zero', selected: false, onTap: onResetZero),
            _ToolChip(
              label: wakeLocked ? 'Wake Lock' : 'Wake Lock',
              selected: wakeLocked,
              onTap: onToggleWakeLock,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Tolerance',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withAlpha(50),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: tolerance,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    items: const [
                      DropdownMenuItem(value: 0.1, child: Text('0.1°')),
                      DropdownMenuItem(value: 0.2, child: Text('0.2°')),
                      DropdownMenuItem(value: 0.5, child: Text('0.5°')),
                      DropdownMenuItem(value: 1.0, child: Text('1.0°')),
                    ],
                    onChanged: (v) {
                      if (v != null) onToleranceChanged(v);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withAlpha(180),
            ),
          ),
        ),
      ),
    );
  }
}
