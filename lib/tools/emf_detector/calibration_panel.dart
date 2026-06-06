import 'package:flutter/material.dart';
import 'emf_colors.dart';
import 'detector_state.dart';

class CalibrationPanel extends StatelessWidget {
  final DetectorState state;

  const CalibrationPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            // Calibrate Button
            ElevatedButton.icon(
              onPressed: state.isScanning ? state.calibrateBaseline : null,
              icon: const Icon(Icons.gps_fixed, size: 14),
              label: const Text(
                'CALIBRATE BASELINE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: EmfColors.darkBgDeep,
                backgroundColor: EmfColors.neonEmerald,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            // Reset Button
            OutlinedButton(
              onPressed: state.isScanning && state.isCalibrated
                  ? state.resetBaseline
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey[600],
                side: BorderSide(
                  color: state.isScanning && state.isCalibrated
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'RESET',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          state.isCalibrated
              ? 'Zero-offset applied: X:${state.baselineX.toStringAsFixed(1)} Y:${state.baselineY.toStringAsFixed(1)} Z:${state.baselineZ.toStringAsFixed(1)}'
              : 'Calibrate in open space to filter ambient Earth magnetic fields.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: state.isCalibrated
                ? EmfColors.neonEmerald.withValues(alpha: 0.8)
                : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
