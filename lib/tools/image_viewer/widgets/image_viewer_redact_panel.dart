import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image/image.dart' as img;

class ImageViewerRedactPanel extends StatefulWidget {
  final ui.Image image;
  final img.Image? decodedImage;
  final Function(
    int x,
    int y,
    int width,
    int height,
    String redactType,
    double intensity,
    Color? color,
  )
  onRedactApplied;
  final VoidCallback onRedactCancelled;

  const ImageViewerRedactPanel({
    super.key,
    required this.image,
    this.decodedImage,
    required this.onRedactApplied,
    required this.onRedactCancelled,
  });

  @override
  State<ImageViewerRedactPanel> createState() => _ImageViewerRedactPanelState();
}

class _ImageViewerRedactPanelState extends State<ImageViewerRedactPanel> {
  late int _imageWidth;
  late int _imageHeight;

  // Normalized coordinates (0.0 to 1.0) of the redact box relative to the image
  Rect _normalizedRedactRect = const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5);

  String _redactType = 'solid'; // 'solid', 'pixelate', 'blur'
  double _intensity =
      15.0; // Slider value for pixelate (block size) or blur (radius)
  Color _solidColor = Colors.black; // Color for solid redact type
  bool _isDragging =
      false; // Performance flag to show fast placeholder during drag/resize

  final ScrollController _styleScrollController = ScrollController();

  static const List<Color> _swatchColors = [
    Colors.black,
    Colors.white,
    Colors.grey,
    Color(0xFFF44336), // Red
    Color(0xFFFFC107), // Amber/Yellow
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
  ];

  @override
  void initState() {
    super.initState();
    _imageWidth = widget.image.width;
    _imageHeight = widget.image.height;
  }

  @override
  void dispose() {
    _styleScrollController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _redactType = type;
      if (type == 'pixelate') {
        _intensity = 15.0;
      } else if (type == 'blur') {
        _intensity = 15.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasIntensity = _redactType == 'pixelate' || _redactType == 'blur';
    final isSolid = _redactType == 'solid';

    return Column(
      children: [
        // Redact style selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.colorScheme.surfaceContainerHigh,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent &&
                      event.scrollDelta.dy != 0) {
                    _styleScrollController.animateTo(
                      _styleScrollController.offset + event.scrollDelta.dy,
                      duration: const Duration(milliseconds: 80),
                      curve: Curves.linear,
                    );
                  }
                },
                child: Scrollbar(
                  controller: _styleScrollController,
                  child: SingleChildScrollView(
                    controller: _styleScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        _RedactStyleButton(
                          label: 'Solid',
                          isActive: isSolid,
                          onPressed: () => _onTypeChanged('solid'),
                        ),
                        const SizedBox(width: 8),
                        _RedactStyleButton(
                          label: 'Pixelate',
                          isActive: _redactType == 'pixelate',
                          onPressed: () => _onTypeChanged('pixelate'),
                        ),
                        const SizedBox(width: 8),
                        _RedactStyleButton(
                          label: 'Blur',
                          isActive: _redactType == 'blur',
                          onPressed: () => _onTypeChanged('blur'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isSolid) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Color: ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _swatchColors.map((color) {
                          return _ColorSwatch(
                            color: color,
                            isSelected:
                                _solidColor.toARGB32() == color.toARGB32(),
                            onTap: () {
                              setState(() {
                                _solidColor = color;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
              if (hasIntensity) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _redactType == 'pixelate'
                            ? 'Block Size: ${_intensity.round()} px'
                            : 'Blur Radius: ${_intensity.round()} px',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Slider(
                        value: _intensity,
                        min: 4,
                        max: 60,
                        divisions: 56,
                        onChanged: (val) {
                          setState(() {
                            _intensity = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Interactive Redact Editor area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
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
                dispW = containerW;
                dispH = containerW / imgRatio;
                offsetX = 0;
                offsetY = (containerH - dispH) / 2;
              } else {
                dispH = containerH;
                dispW = containerH * imgRatio;
                offsetX = (containerW - dispW) / 2;
                offsetY = 0;
              }

              return Stack(
                children: [
                  // Original Image
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    width: dispW,
                    height: dispH,
                    child: RawImage(image: widget.image, fit: BoxFit.fill),
                  ),

                  // Overlay and draggable redact box
                  Positioned.fill(
                    child: _RedactOverlay(
                      image: widget.image,
                      decodedImage: widget.decodedImage,
                      redactRectNormalized: _normalizedRedactRect,
                      imageOffsetX: offsetX,
                      imageOffsetY: offsetY,
                      imageDispW: dispW,
                      imageDispH: dispH,
                      redactType: _redactType,
                      intensity: _intensity,
                      solidColor: _solidColor,
                      isDragging: _isDragging,
                      onDragStart: () {
                        setState(() {
                          _isDragging = true;
                        });
                      },
                      onDragEnd: () {
                        setState(() {
                          _isDragging = false;
                        });
                      },
                      onRectChanged: (newRectNormalized) {
                        setState(() {
                          _normalizedRedactRect = newRectNormalized;
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
                onPressed: widget.onRedactCancelled,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  final int x = (_normalizedRedactRect.left * _imageWidth)
                      .round()
                      .clamp(0, _imageWidth - 1);
                  final int y = (_normalizedRedactRect.top * _imageHeight)
                      .round()
                      .clamp(0, _imageHeight - 1);
                  int w = (_normalizedRedactRect.width * _imageWidth).round();
                  int h = (_normalizedRedactRect.height * _imageHeight).round();

                  w = w.clamp(1, _imageWidth - x);
                  h = h.clamp(1, _imageHeight - y);

                  // Calculate display width in this build
                  final double containerW = MediaQuery.of(context).size.width;
                  final double containerH = MediaQuery.of(context).size.height;
                  final double imgRatio = _imageWidth / _imageHeight;
                  final double containerRatio = containerW / containerH;
                  final double dispW = imgRatio > containerRatio
                      ? containerW
                      : containerH * imgRatio;

                  // Scale intensity based on the display-to-original ratio so the pixelation matches preview
                  final double scaleRelation =
                      _imageWidth / (dispW > 0 ? dispW : _imageWidth);
                  final double scaledIntensity = _intensity * scaleRelation;

                  widget.onRedactApplied(
                    x,
                    y,
                    w,
                    h,
                    _redactType,
                    scaledIntensity,
                    _redactType == 'solid' ? _solidColor : null,
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Apply Redaction'),
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

class _RedactStyleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _RedactStyleButton({
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

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWhite = color == Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isWhite ? Colors.grey.shade400 : Colors.transparent),
            width: isSelected ? 3.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 16,
                color: isWhite ? Colors.black : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _RedactOverlay extends StatefulWidget {
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
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<Rect> onRectChanged;

  const _RedactOverlay({
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
    required this.onDragStart,
    required this.onDragEnd,
    required this.onRectChanged,
  });

  @override
  State<_RedactOverlay> createState() => _RedactOverlayState();
}

class _RedactOverlayState extends State<_RedactOverlay> {
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
                  color: theme.colorScheme.primary,
                  width: 2.0,
                ),
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
    switch (widget.redactType) {
      case 'solid':
        return Container(color: widget.solidColor);
      case 'pixelate':
        if (widget.isDragging) {
          return Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: const Center(
              child: Icon(Icons.grid_on, color: Colors.white70, size: 24),
            ),
          );
        }
        if (widget.decodedImage == null) {
          return Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return CustomPaint(
          painter: _PixelatePainter(
            decodedImage: widget.decodedImage!,
            normalizedRect: widget.redactRectNormalized,
            blockSize: widget.intensity,
          ),
        );
      case 'blur':
        if (widget.isDragging) {
          return Container(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: const Center(
              child: Icon(Icons.blur_on, color: Colors.white70, size: 24),
            ),
          );
        }
        return ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: widget.intensity,
              sigmaY: widget.intensity,
            ),
            child: Container(color: Colors.transparent),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
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

class _PixelatePainter extends CustomPainter {
  final img.Image decodedImage;
  final Rect normalizedRect;
  final double blockSize;

  _PixelatePainter({
    required this.decodedImage,
    required this.normalizedRect,
    required this.blockSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double stepX = blockSize;
    final double stepY = blockSize;

    final paint = Paint()..style = PaintingStyle.fill;

    // Map starting coords of redact box to decoded image pixels
    final double srcLeft = normalizedRect.left * decodedImage.width;
    final double srcTop = normalizedRect.top * decodedImage.height;
    final double srcWidth = normalizedRect.width * decodedImage.width;
    final double srcHeight = normalizedRect.height * decodedImage.height;

    for (double y = 0; y < size.height; y += stepY) {
      for (double x = 0; x < size.width; x += stepX) {
        // Calculate original coordinate to sample color from the center of this block
        final double sampleX =
            srcLeft + (x + stepX / 2) * (srcWidth / size.width);
        final double sampleY =
            srcTop + (y + stepY / 2) * (srcHeight / size.height);

        final int clampX = sampleX.round().clamp(0, decodedImage.width - 1);
        final int clampY = sampleY.round().clamp(0, decodedImage.height - 1);

        final pixel = decodedImage.getPixel(clampX, clampY);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();
        final int a = pixel.a.toInt();

        paint.color = Color.fromARGB(a, r, g, b);

        final double w = math.min(stepX, size.width - x);
        final double h = math.min(stepY, size.height - y);

        canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelatePainter oldDelegate) {
    return oldDelegate.decodedImage != decodedImage ||
        oldDelegate.normalizedRect != normalizedRect ||
        oldDelegate.blockSize != blockSize;
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
