import 'package:flutter/material.dart';
import 'package:tool_lab/widgets/qr_scanner/qr_camera_scanner.dart';

class PairingScannerContent extends StatelessWidget {
  final String hint;
  final bool sending;
  final int scanGeneration;
  final Color accentColor;
  final ValueChanged<String> onDetected;

  const PairingScannerContent({
    super.key,
    required this.hint,
    required this.sending,
    required this.scanGeneration,
    required this.accentColor,
    required this.onDetected,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(hint, textAlign: TextAlign.center),
      ),
      Expanded(
        child: sending
            ? const Center(child: CircularProgressIndicator())
            : QrCameraScanner(
                key: ValueKey(scanGeneration),
                accentColor: accentColor,
                onDetected: onDetected,
              ),
      ),
    ],
  );
}
