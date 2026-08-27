import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import '../emf_colors.dart';
import '../emf_reading.dart';
import '../detector_state.dart';
import 'axis_bar.dart';

class VectorReadoutCard extends StatelessWidget {
  final DetectorState state;
  final EmfReading current;

  const VectorReadoutCard({
    super.key,
    required this.state,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
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
              Text(
                l10n.emfThreeAxisVectorReadout,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              Text(
                state.isScanning ? l10n.emfLiveSensors : l10n.emfPaused,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: state.isScanning
                      ? EmfColors.neonCyan
                      : EmfColors.inkDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AxisBar(
            label: 'X',
            value: state.isScanning ? current.deltaX : 0.0,
            activeColor: EmfColors.neonCyan,
            isScanning: state.isScanning,
          ),
          AxisBar(
            label: 'Y',
            value: state.isScanning ? current.deltaY : 0.0,
            activeColor: EmfColors.neonEmerald,
            isScanning: state.isScanning,
          ),
          AxisBar(
            label: 'Z',
            value: state.isScanning ? current.deltaZ : 0.0,
            activeColor: EmfColors.neonPink,
            isScanning: state.isScanning,
          ),
        ],
      ),
    );
  }
}
