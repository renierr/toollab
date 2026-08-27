import 'package:flutter/material.dart';
import '../emf_colors.dart';

class CableDetectedBanner extends StatelessWidget {
  final bool isScanning;
  final bool isWarning;

  const CableDetectedBanner({
    super.key,
    required this.isScanning,
    required this.isWarning,
  });

  @override
  Widget build(BuildContext context) {
    final Color themeColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (!isScanning) {
      themeColor = Colors.white.withValues(alpha: 0.15);
      icon = Icons.sensors_off_outlined;
      title = 'SCANNER PAUSED';
      subtitle = 'Tap START SCANNING below to search for hidden wall cables.';
    } else if (isWarning) {
      themeColor = EmfColors.neonPink;
      icon = Icons.warning_amber_rounded;
      title = 'CABLE / METAL DETECTED';
      subtitle = 'Strong local magnetic field anomaly detected inside wall.';
    } else {
      themeColor = EmfColors.neonEmerald;
      icon = Icons.check_circle_outline;
      title = 'SCANNING ACTIVE - SYSTEM STABLE';
      subtitle = 'No major electromagnetic anomalies detected.';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: themeColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: EmfColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
