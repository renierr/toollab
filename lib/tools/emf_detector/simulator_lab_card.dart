import 'package:flutter/material.dart';
import 'emf_colors.dart';
import 'sensor_service.dart';
import 'detector_state.dart';
import 'preset_chip.dart';
import 'manual_vector_slider.dart';

class SimulatorLabCard extends StatelessWidget {
  final DetectorState state;

  const SimulatorLabCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.isSimulationActive) {
      // Don't clutter UI on actual phones where sensor is active (but allow manual simulator overrides by turning it on)
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: TextButton.icon(
            onPressed: () => state.setSimulationMode(true),
            icon: const Icon(Icons.science_outlined, size: 14),
            label: const Text(
              'OPEN VIRTUAL SENSOR TOOLBOX (DEVELOPER)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[500]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EmfColors.darkBgWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EmfColors.amberYellow.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              const Text(
                '🛠️ DEVELOPER SIMULATION LAB',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: EmfColors.amberYellow,
                ),
              ),
              GestureDetector(
                onTap: () => state.setSimulationMode(false),
                child: const Text(
                  'EXIT SIM',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Simulation Presets Toggle
          Text(
            'SELECT FIELD SCENARIO PRESET',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PresetChip(
                state: state,
                preset: SimulationPreset.none,
                label: 'Earth Normal',
              ),
              PresetChip(
                state: state,
                preset: SimulationPreset.mainsCable,
                label: 'Mains Wire (AC)',
              ),
              PresetChip(
                state: state,
                preset: SimulationPreset.strongMagnet,
                label: 'Magnet Proximity',
              ),
              PresetChip(
                state: state,
                preset: SimulationPreset.ambientNoise,
                label: 'Walk Drift (Drift)',
              ),
            ],
          ),

          const Divider(color: Colors.white10, height: 24),

          // Manual Slider Overrides
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'MANUAL X, Y, Z VECTOR ADJUSTMENTS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                ),
              ),
              if (state.currentPreset == SimulationPreset.none)
                const Text(
                  'MANUAL ACTIVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: EmfColors.neonEmerald,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ManualVectorSlider(
            label: 'X Offset',
            value: state.currentReading?.x ?? 0.0,
            onChanged: (val) {
              state.setSimulationPreset(SimulationPreset.none);
              state.setManualSimulationValues(
                val,
                state.currentReading?.y ?? 0.0,
                state.currentReading?.z ?? 0.0,
              );
            },
          ),
          ManualVectorSlider(
            label: 'Y Offset',
            value: state.currentReading?.y ?? 0.0,
            onChanged: (val) {
              state.setSimulationPreset(SimulationPreset.none);
              state.setManualSimulationValues(
                state.currentReading?.x ?? 0.0,
                val,
                state.currentReading?.z ?? 0.0,
              );
            },
          ),
          ManualVectorSlider(
            label: 'Z Offset',
            value: state.currentReading?.z ?? 0.0,
            onChanged: (val) {
              state.setSimulationPreset(SimulationPreset.none);
              state.setManualSimulationValues(
                state.currentReading?.x ?? 0.0,
                state.currentReading?.y ?? 0.0,
                val,
              );
            },
          ),
        ],
      ),
    );
  }
}
