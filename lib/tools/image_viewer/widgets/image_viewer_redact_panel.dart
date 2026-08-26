import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image/image.dart' as img;
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/tools/image_viewer/utils/image_redact_painters.dart';
import 'package:tool_lab/tools/image_viewer/widgets/image_viewer_redact_overlay.dart';

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
    List<Offset>? relativePathPoints,
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

  // Path drawing state
  List<Offset>? _relativePathPoints;
  bool _isDrawingPath = false;
  List<Offset> _tempDrawingPoints = [];

  // Collapsible header state
  bool _isHeaderExpanded = true;

  final ScrollController _styleScrollController = ScrollController();

  static const List<Color> _swatchColors = [
    Colors.black,
    Colors.white,
    Colors.grey,
    Colors.red,
    Colors.amber,
    Colors.green,
    Colors.blue,
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

  void _finalizeDrawing(double dispW, double dispH) {
    if (_tempDrawingPoints.length < 3) {
      setState(() {
        _isDrawingPath = false;
        _relativePathPoints = null;
      });
      return;
    }

    double minX = _tempDrawingPoints.first.dx;
    double maxX = _tempDrawingPoints.first.dx;
    double minY = _tempDrawingPoints.first.dy;
    double maxY = _tempDrawingPoints.first.dy;
    for (final p in _tempDrawingPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    double w = maxX - minX;
    double h = maxY - minY;
    if (w < 10) {
      minX = math.max(0.0, minX - 5);
      w = 10;
    }
    if (h < 10) {
      minY = math.max(0.0, minY - 5);
      h = 10;
    }

    final double normLeft = (minX / dispW).clamp(0.0, 1.0);
    final double normTop = (minY / dispH).clamp(0.0, 1.0);
    final double normWidth = (w / dispW).clamp(0.0, 1.0 - normLeft);
    final double normHeight = (h / dispH).clamp(0.0, 1.0 - normTop);
    final normRect = Rect.fromLTWH(normLeft, normTop, normWidth, normHeight);

    final List<Offset> relativePoints = [];
    for (final p in _tempDrawingPoints) {
      final rx = ((p.dx - minX) / w).clamp(0.0, 1.0);
      final ry = ((p.dy - minY) / h).clamp(0.0, 1.0);
      relativePoints.add(Offset(rx, ry));
    }

    setState(() {
      _normalizedRedactRect = normRect;
      _relativePathPoints = relativePoints;
      _isDrawingPath = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasIntensity = _redactType == 'pixelate' || _redactType == 'blur';
    final isSolid = _redactType == 'solid';

    return Column(
      children: [
        // Collapsible header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: theme.colorScheme.surfaceContainerHigh,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.imgViewRedactStyleHeader,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isHeaderExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isHeaderExpanded = !_isHeaderExpanded;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Settings panel
        if (_isHeaderExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Shape selector using Wrap to prevent overflow on small screens
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.imgViewShapeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ChoiceChip(
                      label: Text(l10n.imgViewShapeRectangle),
                      selected: _relativePathPoints == null,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _relativePathPoints = null;
                            _isDrawingPath = false;
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Text(l10n.imgViewShapeFreehand),
                      selected: _relativePathPoints != null,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isDrawingPath = true;
                            _tempDrawingPoints = [];
                          });
                        }
                      },
                    ),
                    if (_relativePathPoints != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isDrawingPath = true;
                            _tempDrawingPoints = [];
                          });
                        },
                        icon: const Icon(Icons.gesture, size: 16),
                        label: Text(l10n.imgViewRedraw),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Style selector
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
                            label: l10n.imgViewStyleSolid,
                            isActive: isSolid,
                            onPressed: () => _onTypeChanged('solid'),
                          ),
                          const SizedBox(width: 8),
                          _RedactStyleButton(
                            label: l10n.imgViewStylePixelate,
                            isActive: _redactType == 'pixelate',
                            onPressed: () => _onTypeChanged('pixelate'),
                          ),
                          const SizedBox(width: 8),
                          _RedactStyleButton(
                            label: l10n.imgViewStyleBlur,
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
                        l10n.imgViewColorLabel,
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
                              ? l10n.imgViewBlockSize(_intensity.round())
                              : l10n.imgViewBlurRadius(_intensity.round()),
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

                  if (_isDrawingPath) ...[
                    // Drawing canvas
                    Positioned(
                      left: offsetX,
                      top: offsetY,
                      width: dispW,
                      height: dispH,
                      child: GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _tempDrawingPoints = [details.localPosition];
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            final localPos = details.localPosition;
                            if (localPos.dx >= 0 &&
                                localPos.dx <= dispW &&
                                localPos.dy >= 0 &&
                                localPos.dy <= dispH) {
                              _tempDrawingPoints.add(localPos);
                            }
                          });
                        },
                        onPanEnd: (_) {
                          _finalizeDrawing(dispW, dispH);
                        },
                        child: CustomPaint(
                          painter: DrawingPainter(
                            points: _tempDrawingPoints,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    // Hint banner (hidden once user starts drawing)
                    if (_tempDrawingPoints.isEmpty)
                      Positioned(
                        top: 8,
                        left: 16,
                        right: 16,
                        child: Center(
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: theme.colorScheme.primaryContainer,
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                l10n.imgViewRedactHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ] else
                    // Overlay and draggable redact box
                    Positioned.fill(
                      child: ImageViewerRedactOverlay(
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
                        relativePathPoints: _relativePathPoints,
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
                label: Text(l10n.commonCancel),
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

                  final double containerW = MediaQuery.sizeOf(context).width;
                  final double containerH = MediaQuery.sizeOf(context).height;
                  final double imgRatio = _imageWidth / _imageHeight;
                  final double containerRatio = containerW / containerH;
                  final double dispW = imgRatio > containerRatio
                      ? containerW
                      : containerH * imgRatio;

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
                    _relativePathPoints,
                  );
                },
                icon: const Icon(Icons.check),
                label: Text(l10n.imgViewApplyRedaction),
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
