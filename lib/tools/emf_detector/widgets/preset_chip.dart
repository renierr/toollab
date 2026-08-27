import 'package:flutter/material.dart';
import '../emf_colors.dart';
import '../sensor_service.dart';
import '../detector_state.dart';

class PresetChip extends StatelessWidget {
  final DetectorState state;
  final SimulationPreset preset;
  final String label;

  const PresetChip({
    super.key,
    required this.state,
    required this.preset,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = state.currentPreset == preset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isSelected ? EmfColors.darkBgDeep : EmfColors.inkChip,
        ),
      ),
      selected: isSelected,
      selectedColor: EmfColors.amberYellow,
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      side: BorderSide(
        color: isSelected
            ? EmfColors.amberYellow
            : Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onSelected: (selected) {
        if (selected) {
          state.setSimulationPreset(preset);
        }
      },
    );
  }
}
