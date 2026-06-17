import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'qr_scan_line_overlay.dart';

/// Live camera QR scanner (Android only — desktop has no camera streaming).
/// Wraps flutter_zxing's [ReaderWidget] and overlays an animated viewfinder.
/// Reports the first valid decode once via [onDetected].
class QrCameraScanner extends StatefulWidget {
  final Color accentColor;
  final ValueChanged<String> onDetected;

  const QrCameraScanner({
    super.key,
    required this.accentColor,
    required this.onDetected,
  });

  @override
  State<QrCameraScanner> createState() => _QrCameraScannerState();
}

class _QrCameraScannerState extends State<QrCameraScanner> {
  bool _handled = false;

  void _onScan(Code code) {
    if (_handled) return;
    final text = code.text;
    if (code.isValid && text != null && text.isNotEmpty) {
      _handled = true;
      widget.onDetected(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ReaderWidget(
          onScan: _onScan,
          showScannerOverlay: false,
          showGallery: false,
          tryHarder: true,
          tryInverted: true,
          tryRotate: true,
          cropPercent: 0.8,
          codeFormat: Format.any,
          loading: const Center(child: CircularProgressIndicator()),
        ),
        QrScanLineOverlay(accentColor: widget.accentColor),
      ],
    );
  }
}
