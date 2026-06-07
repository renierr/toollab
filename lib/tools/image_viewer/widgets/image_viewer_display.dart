import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageViewerDisplay extends StatefulWidget {
  final ui.Image image;
  final TransformationController transformationController;
  final VoidCallback onResetZoom;

  const ImageViewerDisplay({
    super.key,
    required this.image,
    required this.transformationController,
    required this.onResetZoom,
  });

  @override
  State<ImageViewerDisplay> createState() => _ImageViewerDisplayState();
}

class _ImageViewerDisplayState extends State<ImageViewerDisplay> {
  double _zoomScale = 1.0;

  @override
  void initState() {
    super.initState();
    widget.transformationController.addListener(_handleZoomChange);
  }

  @override
  void didUpdateWidget(covariant ImageViewerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      oldWidget.transformationController.removeListener(_handleZoomChange);
      widget.transformationController.addListener(_handleZoomChange);
    }
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_handleZoomChange);
    super.dispose();
  }

  void _handleZoomChange() {
    final scale = widget.transformationController.value.getMaxScaleOnAxis();
    if (scale != _zoomScale) {
      setState(() {
        _zoomScale = scale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final checkerboardColor1 = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE0E0E0);
    final checkerboardColor2 = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF5F5F5);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Checkerboard background
          Positioned.fill(
            child: CustomPaint(
              painter: CheckerboardPainter(
                color1: checkerboardColor1,
                color2: checkerboardColor2,
              ),
            ),
          ),
          // Interactive image viewer
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: widget.transformationController,
              minScale: 0.1,
              maxScale: 10.0,
              child: Center(
                child: RawImage(image: widget.image, fit: BoxFit.contain),
              ),
            ),
          ),
          // Floating overlay: Zoom level and Reset Zoom button
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_in,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(_zoomScale * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if ((_zoomScale - 1.0).abs() > 0.01) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 16,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: widget.onResetZoom,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckerboardPainter extends CustomPainter {
  final double squareSize;
  final Color color1;
  final Color color2;

  CheckerboardPainter({
    this.squareSize = 12.0,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven =
            ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) =>
      oldDelegate.squareSize != squareSize ||
      oldDelegate.color1 != color1 ||
      oldDelegate.color2 != color2;
}
