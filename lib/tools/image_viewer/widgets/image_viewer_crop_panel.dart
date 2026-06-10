import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ImageViewerCropPanel extends StatefulWidget {
  final ui.Image image;
  final Function(int x, int y, int width, int height) onCropApplied;
  final VoidCallback onCropCancelled;

  const ImageViewerCropPanel({
    super.key,
    required this.image,
    required this.onCropApplied,
    required this.onCropCancelled,
  });

  @override
  State<ImageViewerCropPanel> createState() => _ImageViewerCropPanelState();
}

class _ImageViewerCropPanelState extends State<ImageViewerCropPanel> {
  // Image dimensions
  late int _imageWidth;
  late int _imageHeight;

  // Crop Box state: normalized (0.0 to 1.0) coordinates relative to the IMAGE bounds.
  // Using normalized coordinates ensures that changes in screen layout or orientation
  // don't invalidate the crop rect.
  Rect _normalizedCropRect = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);

  double? _aspectRatio; // null means Freeform
  String _activePreset = 'Free';

  final ScrollController _presetScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _imageWidth = widget.image.width;
    _imageHeight = widget.image.height;
  }

  @override
  void dispose() {
    _presetScrollController.dispose();
    super.dispose();
  }

  void _applyPreset(double? ratio, String label) {
    setState(() {
      _aspectRatio = ratio;
      _activePreset = label;
      if (ratio != null) {
        // Center a box with the specified aspect ratio
        double w = 0.8;
        double h = 0.8;
        final imageRatio = _imageWidth / _imageHeight;

        if (ratio > imageRatio) {
          // Box is wider than image aspect ratio allows at 0.8 width
          w = 0.8;
          h = w / ratio * imageRatio;
        } else {
          // Box is taller
          h = 0.8;
          w = h * ratio / imageRatio;
        }

        // Limit to bounds
        w = w.clamp(0.1, 1.0);
        h = h.clamp(0.1, 1.0);

        _normalizedCropRect = Rect.fromLTWH((1.0 - w) / 2, (1.0 - h) / 2, w, h);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Presets bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surfaceContainerHigh,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
                _presetScrollController.animateTo(
                  _presetScrollController.offset + event.scrollDelta.dy,
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.linear,
                );
              }
            },
            child: Scrollbar(
              controller: _presetScrollController,
              child: SingleChildScrollView(
                controller: _presetScrollController,
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Row(
                  children: [
                    _PresetButton(
                      label: 'Free',
                      isActive: _activePreset == 'Free',
                      onPressed: () => _applyPreset(null, 'Free'),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: '1:1 Square',
                      isActive: _activePreset == '1:1 Square',
                      onPressed: () => _applyPreset(1.0, '1:1 Square'),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: '16:9 Widescreen',
                      isActive: _activePreset == '16:9 Widescreen',
                      onPressed: () => _applyPreset(16 / 9, '16:9 Widescreen'),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: '4:3 Standard',
                      isActive: _activePreset == '4:3 Standard',
                      onPressed: () => _applyPreset(4 / 3, '4:3 Standard'),
                    ),
                    const SizedBox(width: 8),
                    _PresetButton(
                      label: '3:2 Photo',
                      isActive: _activePreset == '3:2 Photo',
                      onPressed: () => _applyPreset(3 / 2, '3:2 Photo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Interactive Editor area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate displayed image bounds inside the constraints
              final double containerW = constraints.maxWidth;
              final double containerH = constraints.maxHeight;

              if (containerW <= 0 || containerH <= 0) {
                return const SizedBox.shrink();
              }

              final double imgRatio = _imageWidth / _imageHeight;
              final double containerRatio = containerW / containerH;

              double dispW;
              double dispH;
              double offsetX;
              double offsetY;

              if (imgRatio > containerRatio) {
                // Width constrained
                dispW = containerW;
                dispH = containerW / imgRatio;
                offsetX = 0;
                offsetY = (containerH - dispH) / 2;
              } else {
                // Height constrained
                dispH = containerH;
                dispW = containerH * imgRatio;
                offsetX = (containerW - dispW) / 2;
                offsetY = 0;
              }

              return Stack(
                children: [
                  // Actual Image (fitted inside display bounds)
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    width: dispW,
                    height: dispH,
                    child: RawImage(image: widget.image, fit: BoxFit.fill),
                  ),

                  // Overlay and draggable crop box
                  Positioned.fill(
                    child: _CropOverlay(
                      cropRectNormalized: _normalizedCropRect,
                      imageOffsetX: offsetX,
                      imageOffsetY: offsetY,
                      imageDispW: dispW,
                      imageDispH: dispH,
                      aspectRatio: _aspectRatio,
                      onRectChanged: (newRectNormalized) {
                        setState(() {
                          _normalizedCropRect = newRectNormalized;
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Action controls
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceContainerHigh,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: widget.onCropCancelled,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // Map normalized rect back to original image pixels
                  final int x = (_normalizedCropRect.left * _imageWidth)
                      .round()
                      .clamp(0, _imageWidth - 1);
                  final int y = (_normalizedCropRect.top * _imageHeight)
                      .round()
                      .clamp(0, _imageHeight - 1);
                  int w = (_normalizedCropRect.width * _imageWidth).round();
                  int h = (_normalizedCropRect.height * _imageHeight).round();

                  // Clamp dimensions to make sure we don't go out of bounds
                  w = w.clamp(1, _imageWidth - x);
                  h = h.clamp(1, _imageHeight - y);

                  widget.onCropApplied(x, y, w, h);
                },
                icon: const Icon(Icons.check),
                label: const Text('Apply Crop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _PresetButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => onPressed(),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _CropOverlay extends StatelessWidget {
  final Rect cropRectNormalized;
  final double imageOffsetX;
  final double imageOffsetY;
  final double imageDispW;
  final double imageDispH;
  final double? aspectRatio;
  final ValueChanged<Rect> onRectChanged;

  const _CropOverlay({
    required this.cropRectNormalized,
    required this.imageOffsetX,
    required this.imageOffsetY,
    required this.imageDispW,
    required this.imageDispH,
    required this.aspectRatio,
    required this.onRectChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Screen coordinates of the crop box
    final double left = imageOffsetX + cropRectNormalized.left * imageDispW;
    final double top = imageOffsetY + cropRectNormalized.top * imageDispH;
    final double width = cropRectNormalized.width * imageDispW;
    final double height = cropRectNormalized.height * imageDispH;

    return Stack(
      children: [
        // Semi-transparent dimming background
        Positioned.fill(
          child: CustomPaint(
            painter: _DimPainter(
              cropRect: Rect.fromLTWH(left, top, width, height),
              imageRect: Rect.fromLTWH(
                imageOffsetX,
                imageOffsetY,
                imageDispW,
                imageDispH,
              ),
            ),
          ),
        ),

        // Draggable box surface for moving the entire crop rect
        Positioned(
          left: left + 12,
          top: top + 12,
          width: math.max(0, width - 24),
          height: math.max(0, height - 24),
          child: GestureDetector(
            onPanUpdate: (details) {
              // Convert delta to normalized delta
              final double dxNorm = details.delta.dx / imageDispW;
              final double dyNorm = details.delta.dy / imageDispH;

              double newLeft = cropRectNormalized.left + dxNorm;
              double newTop = cropRectNormalized.top + dyNorm;

              // Constrain to keep crop box completely inside the image
              newLeft = newLeft.clamp(0.0, 1.0 - cropRectNormalized.width);
              newTop = newTop.clamp(0.0, 1.0 - cropRectNormalized.height);

              onRectChanged(
                Rect.fromLTWH(
                  newLeft,
                  newTop,
                  cropRectNormalized.width,
                  cropRectNormalized.height,
                ),
              );
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Drag handles (corners)
        // Top-Left
        Positioned(
          left: left - 12,
          top: top - 12,
          child: _Handle(
            onDrag: (dx, dy) => _resizeCropBox(dx, dy, top: true, left: true),
          ),
        ),
        // Top-Right
        Positioned(
          left: left + width - 12,
          top: top - 12,
          child: _Handle(
            onDrag: (dx, dy) => _resizeCropBox(dx, dy, top: true, right: true),
          ),
        ),
        // Bottom-Left
        Positioned(
          left: left - 12,
          top: top + height - 12,
          child: _Handle(
            onDrag: (dx, dy) =>
                _resizeCropBox(dx, dy, bottom: true, left: true),
          ),
        ),
        // Bottom-Right
        Positioned(
          left: left + width - 12,
          top: top + height - 12,
          child: _Handle(
            onDrag: (dx, dy) =>
                _resizeCropBox(dx, dy, bottom: true, right: true),
          ),
        ),
      ],
    );
  }

  void _resizeCropBox(
    double dx,
    double dy, {
    bool top = false,
    bool bottom = false,
    bool left = false,
    bool right = false,
  }) {
    // Current coordinates in pixels relative to image start
    double pxLeft = cropRectNormalized.left * imageDispW;
    double pxTop = cropRectNormalized.top * imageDispH;
    double pxWidth = cropRectNormalized.width * imageDispW;
    double pxHeight = cropRectNormalized.height * imageDispH;

    final double minSize = 32.0;

    if (aspectRatio == null) {
      // Freeform scaling
      if (left) {
        final double newLeft = (pxLeft + dx).clamp(
          0.0,
          pxLeft + pxWidth - minSize,
        );
        pxWidth = pxWidth + (pxLeft - newLeft);
        pxLeft = newLeft;
      }
      if (right) {
        pxWidth = (pxWidth + dx).clamp(minSize, imageDispW - pxLeft);
      }
      if (top) {
        final double newTop = (pxTop + dy).clamp(
          0.0,
          pxTop + pxHeight - minSize,
        );
        pxHeight = pxHeight + (pxTop - newTop);
        pxTop = newTop;
      }
      if (bottom) {
        pxHeight = (pxHeight + dy).clamp(minSize, imageDispH - pxTop);
      }
    } else {
      // Aspect ratio locked scaling.
      // We adjust based on the primary dragging axis.
      if (left && top) {
        // Resize from Top-Left
        double proposedW = pxWidth - dx;
        double proposedH = proposedW / aspectRatio!;
        if (proposedW >= minSize &&
            proposedH >= minSize &&
            (pxLeft + pxWidth - proposedW) >= 0 &&
            (pxTop + pxHeight - proposedH) >= 0) {
          pxLeft = pxLeft + pxWidth - proposedW;
          pxTop = pxTop + pxHeight - proposedH;
          pxWidth = proposedW;
          pxHeight = proposedH;
        }
      } else if (right && top) {
        // Resize from Top-Right
        double proposedW = pxWidth + dx;
        double proposedH = proposedW / aspectRatio!;
        if (proposedW >= minSize &&
            proposedH >= minSize &&
            (pxLeft + proposedW) <= imageDispW &&
            (pxTop + pxHeight - proposedH) >= 0) {
          pxTop = pxTop + pxHeight - proposedH;
          pxWidth = proposedW;
          pxHeight = proposedH;
        }
      } else if (left && bottom) {
        // Resize from Bottom-Left
        double proposedW = pxWidth - dx;
        double proposedH = proposedW / aspectRatio!;
        if (proposedW >= minSize &&
            proposedH >= minSize &&
            (pxLeft + pxWidth - proposedW) >= 0 &&
            (pxTop + proposedH) <= imageDispH) {
          pxLeft = pxLeft + pxWidth - proposedW;
          pxWidth = proposedW;
          pxHeight = proposedH;
        }
      } else if (right && bottom) {
        // Resize from Bottom-Right
        double proposedW = pxWidth + dx;
        double proposedH = proposedW / aspectRatio!;
        if (proposedW >= minSize &&
            proposedH >= minSize &&
            (pxLeft + proposedW) <= imageDispW &&
            (pxTop + proposedH) <= imageDispH) {
          pxWidth = proposedW;
          pxHeight = proposedH;
        }
      }
    }

    // Convert back to normalized coordinates
    onRectChanged(
      Rect.fromLTWH(
        (pxLeft / imageDispW).clamp(0.0, 1.0),
        (pxTop / imageDispH).clamp(0.0, 1.0),
        (pxWidth / imageDispW).clamp(0.0, 1.0),
        (pxHeight / imageDispH).clamp(0.0, 1.0),
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect cropRect;
  final Rect imageRect;

  _DimPainter({required this.cropRect, required this.imageRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    // Build the paths: dim the image bounds except the crop bounds
    final imagePath = Path()..addRect(imageRect);
    final cropPath = Path()..addRect(cropRect);

    final dimPath = Path.combine(PathOperation.difference, imagePath, cropPath);
    canvas.drawPath(dimPath, dimPaint);

    // Draw crop box border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    // Draw grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double wThird = cropRect.width / 3.0;
    final double hThird = cropRect.height / 3.0;

    canvas.drawLine(
      Offset(cropRect.left + wThird, cropRect.top),
      Offset(cropRect.left + wThird, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + 2 * wThird, cropRect.top),
      Offset(cropRect.left + 2 * wThird, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + hThird),
      Offset(cropRect.right, cropRect.top + hThird),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + 2 * hThird),
      Offset(cropRect.right, cropRect.top + 2 * hThird),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DimPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.imageRect != imageRect;
  }
}

class _Handle extends StatelessWidget {
  final Function(double dx, double dy) onDrag;

  const _Handle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        onDrag(details.delta.dx, details.delta.dy);
      },
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        color: Colors.transparent, // expand hit area
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
