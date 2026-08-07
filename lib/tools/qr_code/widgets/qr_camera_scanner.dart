import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'camera_zoom_overlay.dart';
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
  CameraController? _controller;

  void _onScan(Code code) {
    if (_handled) return;
    final text = code.text;
    if (code.isValid && text != null && text.isNotEmpty) {
      _handled = true;
      widget.onDetected(text);
    }
  }

  Future<void> _focusAt(Offset relative) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFocusPoint(relative);
      await controller.setExposurePoint(relative);
    } catch (e) {
      debugPrint('[QrCameraScanner] Focus point failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CameraZoomOverlay(
      controller: _controller,
      accentColor: widget.accentColor,
      onTapFocus: _focusAt,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ReaderWidget(
            onScan: _onScan,
            onControllerCreated: (controller, _) {
              if (!mounted) return;
              setState(() => _controller = controller);
            },
            showScannerOverlay: false,
            showGallery: false,
            // Keep zxing's flash/camera buttons clear of our zoom bar.
            actionButtonsAlignment: Alignment.topRight,
            tryHarder: true,
            tryInverted: true,
            tryRotate: true,
            // Own pinch handling lives in CameraZoomOverlay.
            allowPinchZoom: false,
            resolution: ResolutionPreset.veryHigh,
            scanDelay: const Duration(milliseconds: 300),
            cropPercent: 0.8,
            codeFormat: Format.any,
            loading: const Center(child: CircularProgressIndicator()),
          ),
          QrScanLineOverlay(accentColor: widget.accentColor),
        ],
      ),
    );
  }
}
