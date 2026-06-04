import 'package:flutter/material.dart';
import 'detector_state.dart';
import 'feedback_button.dart';

class ScannerControlsCard extends StatelessWidget {
  final DetectorState state;
  final bool wakeLockActive;
  final VoidCallback onToggleWakeLock;

  const ScannerControlsCard({
    super.key,
    required this.state,
    required this.wakeLockActive,
    required this.onToggleWakeLock,
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
          // Main scan toggle + sound/haptics selectors
          Row(
            children: [
              // Main Action Button
              Expanded(
                child: InkWell(
                  onTap: state.toggleScanning,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: state.isScanning
                            ? [const Color(0xFFFF0055), const Color(0xFF9D50BB)]
                            : [
                                const Color(0xFF00F2FE),
                                const Color(0xFF4FACFE),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (state.isScanning
                                      ? const Color(0xFFFF0055)
                                      : const Color(0xFF00F2FE))
                                  .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 16,
                          child: Icon(
                            state.isScanning
                                ? Icons.stop_circle_outlined
                                : Icons.sensors_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 46.0),
                          child: Text(
                            state.isScanning
                                ? 'STOP SCANNING'
                                : 'START SCANNING',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Toggles and sliders row
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 12,
            children: [
              // Sound Toggle
              FeedbackButton(
                icon: state.soundEnabled ? Icons.volume_up : Icons.volume_off,
                label: 'AUDIO TICK',
                active: state.soundEnabled,
                onTap: state.toggleSound,
              ),

              // Haptic Toggle
              FeedbackButton(
                icon: state.hapticsEnabled ? Icons.vibration : Icons.mobile_off,
                label: 'HAPTICS',
                active: state.hapticsEnabled,
                onTap: state.toggleHaptics,
              ),

              // Wake lock toggle
              FeedbackButton(
                icon: wakeLockActive
                    ? Icons.screen_lock_rotation
                    : Icons.screen_rotation,
                label: 'SCREEN ON',
                active: wakeLockActive,
                onTap: onToggleWakeLock,
              ),
            ],
          ),

          const Divider(color: Colors.white10, height: 28),

          // Alert threshold slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    'CABLE TRIGGER THRESHOLD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.grey[400],
                    ),
                  ),
                  Text(
                    '${state.warningThreshold.round()} µT',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD200),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFFFD200),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                  thumbColor: const Color(0xFFFFD200),
                  overlayColor: const Color(0xFFFFD200).withValues(alpha: 0.12),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value: state.warningThreshold,
                  min: 15.0,
                  max: 120.0,
                  onChanged: state.setWarningThreshold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
