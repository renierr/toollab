import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/temp_file_manager.dart';

import 'qr_scan_line_overlay.dart';
import 'yuv_to_jpeg.dart';

/// Camera scanner that uses Google ML Kit Barcode Scanning.
/// Designed for Android. Handles stream conversions and overlays.
class QrMlKitCameraScanner extends StatefulWidget {
  final Color accentColor;
  final TempFileScope scope;
  final Function(
    String text,
    Rect? boundingBox,
    Size? frameSize,
    String? imagePath,
  )
  onDetected;

  const QrMlKitCameraScanner({
    super.key,
    required this.accentColor,
    required this.scope,
    required this.onDetected,
  });

  @override
  State<QrMlKitCameraScanner> createState() => _QrMlKitCameraScannerState();
}

class _QrMlKitCameraScannerState extends State<QrMlKitCameraScanner>
    with DisposeCleanup {
  CameraController? _controller;
  BarcodeScanner? _barcodeScanner;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _handled = false;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      _controller = controller;
      onDispose(() {
        _controller?.dispose();
      });

      await controller.initialize();
      if (!mounted) return;

      _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
      onDispose(() {
        _barcodeScanner?.close();
      });

      await controller.startImageStream((CameraImage image) {
        _processCameraImage(image, camera);
      });

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('[QrMlKitCameraScanner] Init failed: $e');
    }
  }

  Future<void> _processCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_handled || _isProcessing || _barcodeScanner == null) return;

    _isProcessing = true;
    try {
      if (_controller == null) return;
      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation? rotation;
      int rotationCompensation = 0;
      if (Platform.isAndroid) {
        final deviceOrientation = _controller!.value.deviceOrientation;
        final compensation = _orientations[deviceOrientation];
        if (compensation == null) return;

        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation = (sensorOrientation + compensation) % 360;
        } else {
          rotationCompensation = (sensorOrientation - compensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      } else {
        rotationCompensation = sensorOrientation;
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      }

      if (rotation == null) return;

      final inputImage = _inputImageFromCameraImage(image, rotation);
      if (inputImage == null) return;

      final barcodes = await _barcodeScanner!.processImage(inputImage);
      if (_handled || !mounted) return;

      for (final barcode in barcodes) {
        final rawValue = barcode.rawValue;
        final rect = barcode.boundingBox;
        if (rawValue != null && rawValue.isNotEmpty) {
          _handled = true;

          final result = convertNv21ToJpeg(
            image: image,
            rotationDegrees: rotationCompensation,
            barcodeRect: rect,
          );
          final path = await widget.scope.createFile(
            'scan_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
            bytes: result.jpegBytes,
          );
          final rotatedRect = result.rotatedRect;
          final rotatedSize = result.rotatedSize;

          if (mounted) {
            widget.onDetected(rawValue, rotatedRect, rotatedSize, path);
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('[QrMlKitCameraScanner] Process image failed: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final format =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888);

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final deviceRatio = size.width / size.height;

        final cameraRatio = _controller!.value.aspectRatio;
        // Compensate ratio based on orientation
        final double scale = 1 / (cameraRatio * deviceRatio);

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: Transform.scale(
                scale: scale < 1 ? 1 / scale : scale,
                child: Center(child: CameraPreview(_controller!)),
              ),
            ),
            QrScanLineOverlay(accentColor: widget.accentColor),
          ],
        );
      },
    );
  }
}
