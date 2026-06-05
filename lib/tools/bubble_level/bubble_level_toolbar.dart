import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/tool_chip.dart';

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
        // Main Modes/Features
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface.withAlpha(200),
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ToolChip(
              label: '2-Axis',
              selected: mode == LevelMode.mode2d,
              onTap: () => onModeChanged(LevelMode.mode2d),
            ),
            ToolChip(
              label: 'Beam',
              selected: mode == LevelMode.mode1d,
              onTap: () => onModeChanged(LevelMode.mode1d),
            ),
            ToolChip(
              label: 'Ruler',
              selected: rulerVisible,
              onTap: onToggleRuler,
            ),
            if (rulerVisible)
              ToolChip(
                label: 'Calibrate Ruler',
                selected: false,
                onTap: onCalibrateRuler,
              ),
          ],
        ),
        const SizedBox(height: 12),
        // System Quick Toggles (side-by-side)
        Row(
          children: [
            Expanded(
              child: ToolChip(
                icon: rotationLocked
                    ? Icons.screen_lock_portrait
                    : Icons.screen_rotation,
                label: rotationLocked ? 'Locked' : 'Lock Rot.',
                selected: rotationLocked,
                onTap: onToggleRotationLock,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ToolChip(
                icon: Icons.lightbulb_outline,
                label: 'Wake Lock',
                selected: wakeLocked,
                onTap: onToggleWakeLock,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Tolerance Dropdown and Calibration buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'TOLERANCE',
                  style: TextStyle(
                    fontSize: 10,
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
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.gps_fixed, size: 14),
                  label: const Text('Set Zero', style: TextStyle(fontSize: 12)),
                  onPressed: onSetZero,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  onPressed: onResetZero,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
