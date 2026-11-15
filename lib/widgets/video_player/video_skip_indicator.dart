import 'package:flutter/material.dart';

/// Brief badge on the side a swipe skipped to.
class VideoSkipIndicator extends StatelessWidget {
  final bool visible;
  final bool forward;
  final String label;

  const VideoSkipIndicator({
    super.key,
    required this.visible,
    required this.forward,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Align(
          alignment: forward
              ? const Alignment(0.6, 0)
              : const Alignment(-0.6, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    forward ? Icons.fast_forward : Icons.fast_rewind,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
