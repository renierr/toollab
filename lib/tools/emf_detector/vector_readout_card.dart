import 'package:flutter/material.dart';
import 'emf_reading.dart';
import 'detector_state.dart';
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
              const Text(
                '3-AXIS VECTOR READOUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.grey,
                ),
              ),
              Text(
                state.isScanning ? 'LIVE SENSORS' : 'PAUSED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: state.isScanning
                      ? const Color(0xFF00F2FE)
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AxisBar(
            label: 'X',
            value: state.isScanning ? current.deltaX : 0.0,
            activeColor: const Color(0xFF00F2FE), // Cyan
            isScanning: state.isScanning,
          ),
          AxisBar(
            label: 'Y',
            value: state.isScanning ? current.deltaY : 0.0,
            activeColor: const Color(0xFF00FF87), // Emerald
            isScanning: state.isScanning,
          ),
          AxisBar(
            label: 'Z',
            value: state.isScanning ? current.deltaZ : 0.0,
            activeColor: const Color(0xFFFF0055), // Pink/Red
            isScanning: state.isScanning,
          ),
        ],
      ),
    );
  }
}
