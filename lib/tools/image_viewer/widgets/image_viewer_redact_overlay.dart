import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/tools/image_viewer/utils/image_redact_painters.dart';

class ImageViewerRedactOverlay extends StatefulWidget {
  final ui.Image image;
  final img.Image? decodedImage;
  final Rect redactRectNormalized;
  final double imageOffsetX;
  final double imageOffsetY;
  final double imageDispW;
  final double imageDispH;
  final String redactType;
  final double intensity;
  final Color solidColor;
  final bool isDragging;
  final List<Offset>? relativePathPoints;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Rect> onRectChanged;

  const ImageViewerRedactOverlay({
    super.key,
    required this.image,
    this.decodedImage,
    required this.redactRectNormalized,
    required this.imageOffsetX,
    required this.imageOffsetY,
    required this.imageDispW,
    required this.imageDispH,
    required this.redactType,
    required this.intensity,
    required this.solidColor,
    required this.isDragging,
    this.relativePathPoints,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onRectChanged,
  });

  @override
  State<ImageViewerRedactOverlay> createState() =>
      _ImageViewerRedactOverlayState();
}

class _ImageViewerRedactOverlayState extends State<ImageViewerRedactOverlay> {
  Offset? _dragStartOffset;
  Rect? _dragStartRect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Screen coordinates of the redact box
    final double left =
        widget.imageOffsetX +
        widget.redactRectNormalized.left * widget.imageDispW;
    final double top =
        widget.imageOffsetY +
        widget.redactRectNormalized.top * widget.imageDispH;
    final double width = widget.redactRectNormalized.width * widget.imageDispW;
    final double height =
        widget.redactRectNormalized.height * widget.imageDispH;

    return Stack(
      children: [
        // Live Preview of the redacted area (Ignored for pointer events)
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: ClipRect(child: _buildPreviewContent(context)),
          ),
        ),

        // Border of the redact box
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(
                    alpha: widget.relativePathPoints != null ? 0.3 : 1.0,
                  ),
                  width: 2.0,
                ),
              ),
            ),
          ),
        ),

        // Path Outline (if path is defined)
        if (widget.relativePathPoints != null)
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: IgnorePointer(
              child: CustomPaint(
                painter: PathOutlinePainter(
                  points: widget.relativePathPoints!,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

        // Draggable box surface for moving the entire redact rect
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: GestureDetector(
            onPanStart: (details) {
              widget.onDragStart();
              _dragStartOffset = details.globalPosition;
              _dragStartRect = widget.redactRectNormalized;
            },
            onPanEnd: (_) {
              widget.onDragEnd();
              _dragStartOffset = null;
              _dragStartRect = null;
            },
            onPanCancel: () {
              widget.onDragEnd();
              _dragStartOffset = null;
              _dragStartRect = null;
            },
            onPanUpdate: (details) {
              if (_dragStartOffset == null || _dragStartRect == null) return;
              final double dx =
                  details.globalPosition.dx - _dragStartOffset!.dx;
              final double dy =
                  details.globalPosition.dy - _dragStartOffset!.dy;

              final double dxNorm = dx / widget.imageDispW;
              final double dyNorm = dy / widget.imageDispH;

              double newLeft = _dragStartRect!.left + dxNorm;
              double newTop = _dragStartRect!.top + dyNorm;

              newLeft = newLeft.clamp(0.0, 1.0 - _dragStartRect!.width);
              newTop = newTop.clamp(0.0, 1.0 - _dragStartRect!.height);

              widget.onRectChanged(
                Rect.fromLTWH(
                  newLeft,
                  newTop,
                  _dragStartRect!.width,
                  _dragStartRect!.height,
                ),
              );
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Drag handles (corners)
        // Top-Left
        Positioned(
          left: left - 20,
          top: top - 20,
          child: _Handle(
            onDragStart: (globalPos) {
              widget.onDragStart();
              _dragStartOffset = globalPos;
              _dragStartRect = widget.redactRectNormalized;
            },
            onDragEnd: () {
              widget.onDragEnd();
              _dragStartOffset = null;
              _dragStartRect = null;
            },
            onDrag: (globalPos) {
              if (_dragStartOffset == null || _dragStartRect == null) return;
              final double dx = globalPos.dx - _dragStartOffset!.dx;
              final double dy = globalPos.dy - _dragStartOffset!.dy;
              _resizeRedactBox(dx, dy, _dragStartRect!, top: true, left: true);
            },
          ),
        ),
        // Top-Right
        Positioned(
          left: left + width - 20,
          top: top - 20,
          child: _Handle(
            onDragStart: (globalPos) {
              widget.onDragStart();
              _dragStartOffset = globalPos;
              _dragStartRect = widget.redactRectNormalized;
            },
            onDragEnd: () {
              widget.onDragEnd();
              _dragStartOffset = null;
              _dragStartRect = null;
            },
            onDrag: (globalPos) {
              if (_dragStartOffset == null || _dragStartRect == null) return;
              final double dx = globalPos.dx - _dragStartOffset!.dx;
              final double dy = globalPos.dy - _dragStartOffset!.dy;
              _resizeRedactBox(dx, dy, _dragStartRect!, top: true, right: true);
            },
          ),
        ),
        // Bottom-Left
        Positioned(
          left: left - 20,
          top: top + height - 20,
          child: _Handle(
            onDragStart: (globalPos) {
              widget.onDragStart();
              _dragStartOffset = globalPos;
              _dragStartRect = widget.redactRectNormalized;
            },
            onDragEnd: () {
              widget.onDragEnd();
              _dragStartOffset = null;
              _dragStartRect = null;
            },
            onDrag: (globalPos) {
              if (_dragStartOffset == null || _dragStartRect == null) return;
              final double dx = globalPos.dx - _dragStartOffset!.dx;
              final double dy = globalPos.dy - _dragStartOffset!.dy;
              _resizeRedactBox(
                dx,
                dy,
                _dragStartRect!,
                bottom: true,
                left: true,
              );
            },
          ),
        ),
        // Bottom-Right
        Positioned(
          left: left + width - 20,
          top: top + height - 20,
          child: _Handle(
            onDragStart: (globalPos) {
              widget.onDragStart();
              _dragStartOffset = globalPos;
              _dragStartRect = widget.redactRectNormalized;
            },
            onDragEnd: () {
              widget.onDragEnd();
              _dragStartOffset = null;
              _dragStartRect = null;
            },
            onDrag: (globalPos) {
              if (_dragStartOffset == null || _dragStartRect == null) return;
              final double dx = globalPos.dx - _dragStartOffset!.dx;
              final double dy = globalPos.dy - _dragStartOffset!.dy;
              _resizeRedactBox(
                dx,
                dy,
                _dragStartRect!,
                bottom: true,
                right: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    final theme = Theme.of(context);
    Widget content;

    switch (widget.redactType) {
      case 'solid':
        content = Container(color: widget.solidColor);
        break;
      case 'pixelate':
        if (widget.isDragging) {
          content = Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: const Center(
              child: Icon(Icons.grid_on, color: Colors.white70, size: 24),
            ),
          );
        } else if (widget.decodedImage == null) {
          content = Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        } else {
          content = CustomPaint(
            painter: PixelatePainter(
              decodedImage: widget.decodedImage!,
              normalizedRect: widget.redactRectNormalized,
              blockSize: widget.intensity,
            ),
          );
        }
        break;
      case 'blur':
        if (widget.isDragging) {
          content = Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: const Center(
              child: Icon(Icons.blur_on, color: Colors.white70, size: 24),
            ),
          );
        } else {
          content = ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: widget.intensity,
                sigmaY: widget.intensity,
              ),
              child: Container(color: Colors.transparent),
            ),
          );
        }
        break;
      default:
        content = const SizedBox.shrink();
    }

    if (widget.relativePathPoints != null &&
        widget.relativePathPoints!.isNotEmpty) {
      return ClipPath(
        clipper: PathClipper(widget.relativePathPoints!),
        child: content,
      );
    }
    return content;
  }

  void _resizeRedactBox(
    double dx,
    double dy,
    Rect startRect, {
    bool top = false,
    bool bottom = false,
    bool left = false,
    bool right = false,
  }) {
    double pxLeft = startRect.left * widget.imageDispW;
    double pxTop = startRect.top * widget.imageDispH;
    double pxWidth = startRect.width * widget.imageDispW;
    double pxHeight = startRect.height * widget.imageDispH;

    const double minSize = 24.0;

    if (left) {
      final double maxLeft = math.max(0.0, pxLeft + pxWidth - minSize);
      final double newLeft = (pxLeft + dx).clamp(0.0, maxLeft);
      pxWidth = pxWidth + (pxLeft - newLeft);
      pxLeft = newLeft;
    }
    if (right) {
      final double maxWidth = math.max(minSize, widget.imageDispW - pxLeft);
      pxWidth = (pxWidth + dx).clamp(minSize, maxWidth);
    }
    if (top) {
      final double maxTop = math.max(0.0, pxTop + pxHeight - minSize);
      final double newTop = (pxTop + dy).clamp(0.0, maxTop);
      pxHeight = pxHeight + (pxTop - newTop);
      pxTop = newTop;
    }
    if (bottom) {
      final double maxHeight = math.max(minSize, widget.imageDispH - pxTop);
      pxHeight = (pxHeight + dy).clamp(minSize, maxHeight);
    }

    widget.onRectChanged(
      Rect.fromLTWH(
        (pxLeft / widget.imageDispW).clamp(0.0, 1.0),
        (pxTop / widget.imageDispH).clamp(0.0, 1.0),
        (pxWidth / widget.imageDispW).clamp(0.0, 1.0),
        (pxHeight / widget.imageDispH).clamp(0.0, 1.0),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final ValueChanged<Offset> onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Offset> onDrag;

  const _Handle({
    required this.onDrag,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        onDragStart(details.globalPosition);
      },
      onPanEnd: (_) {
        onDragEnd();
      },
      onPanCancel: () {
        onDragEnd();
      },
      onPanUpdate: (details) {
        onDrag(details.globalPosition);
      },
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        color: Colors.transparent,
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
