import 'package:flutter/material.dart';

/// Brief feedback for a gesture on the video: a skip or a volume change.
class VideoGestureBadge extends StatelessWidget {
  final bool visible;
  final Alignment alignment;
  final IconData icon;
  final String label;

  /// Draws a level bar from 0 to 1 under the label.
  final double? level;

  const VideoGestureBadge({
    super.key,
    required this.visible,
    required this.alignment,
    required this.icon,
    required this.label,
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    final level = this.level;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Align(
          alignment: alignment,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(label, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  if (level != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        value: level.clamp(0.0, 1.0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
