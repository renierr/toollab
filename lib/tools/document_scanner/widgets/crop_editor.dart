import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class CropEditor extends StatefulWidget {
  final String originalImagePath;
  final List<Offset> initialCorners;
  final ValueChanged<List<Offset>> onApply;
  final VoidCallback onCancel;
  final Color accentColor;

  const CropEditor({
    super.key,
    required this.originalImagePath,
    required this.initialCorners,
    required this.onApply,
    required this.onCancel,
    required this.accentColor,
  });

  @override
  State<CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<CropEditor> {
  late List<Offset> _corners;
  final List<List<Offset>> _history = [];
  int? _activeHandleIndex;

  // Image metadata loaded dynamically
  int _imageWidth = 1;
  int _imageHeight = 1;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    _corners = List.from(widget.initialCorners);
    _loadImageSize();
  }

  void _loadImageSize() {
    final file = File(widget.originalImagePath);
    if (!file.existsSync()) return;

    final image = Image.file(file);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            if (mounted) {
              setState(() {
                _imageWidth = info.image.width;
                _imageHeight = info.image.height;
                _imageLoaded = true;

                // If initial corners are empty or default to full/fallback, verify bounds
                if (_corners.isEmpty ||
                    _corners.every((c) => c == Offset.zero)) {
                  _corners = [
                    const Offset(0, 0),
                    Offset(_imageWidth.toDouble(), 0),
                    Offset(_imageWidth.toDouble(), _imageHeight.toDouble()),
                    Offset(0, _imageHeight.toDouble()),
                  ];
                }
              });
            }
          }),
        );
  }

  void _saveToHistory() {
    _history.add(List.from(_corners));
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        _corners = _history.removeLast();
      });
    }
  }

  void _reset() {
    _saveToHistory();
    setState(() {
      _corners = [
        const Offset(0, 0),
        Offset(_imageWidth.toDouble(), 0),
        Offset(_imageWidth.toDouble(), _imageHeight.toDouble()),
        Offset(0, _imageHeight.toDouble()),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_imageLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate BoxFit.contain size & offset
        final scale = math.min(
          constraints.maxWidth / _imageWidth,
          constraints.maxHeight / _imageHeight,
        );
        final displayedWidth = _imageWidth * scale;
        final displayedHeight = _imageHeight * scale;
        final offsetX = (constraints.maxWidth - displayedWidth) / 2;
        final offsetY = (constraints.maxHeight - displayedHeight) / 2;

        // Map image coordinates to screen coordinates
        final screenPoints = _corners.map((pt) {
          return Offset(offsetX + pt.dx * scale, offsetY + pt.dy * scale);
        }).toList();

        // Active handle screen coordinates for magnifier
        final activeHandleScreen = _activeHandleIndex != null
            ? screenPoints[_activeHandleIndex!]
            : null;

        // Active handle position relative to the displayed image box (0..displayedWidth, 0..displayedHeight)
        final activeHandleRelative = activeHandleScreen != null
            ? Offset(
                activeHandleScreen.dx - offsetX,
                activeHandleScreen.dy - offsetY,
              )
            : null;

        return Stack(
          children: [
            // Black background and Image container
            Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
            ),

            // Displayed Image
            Center(
              child: SizedBox(
                width: displayedWidth,
                height: displayedHeight,
                child: Image.file(
                  File(widget.originalImagePath),
                  fit: BoxFit.fill,
                ),
              ),
            ),

            // Polygon overlay painter
            Positioned.fill(
              child: CustomPaint(
                painter: _PolygonPainter(
                  points: screenPoints,
                  accentColor: widget.accentColor,
                ),
              ),
            ),

            // Interactive gesture handles
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) {
                  final pos = details.localPosition;
                  // Hit test handles (comfort target of 44x44)
                  int? hitIndex;
                  double minDistance = double.infinity;
                  for (int i = 0; i < screenPoints.length; i++) {
                    final dist = (pos - screenPoints[i]).distance;
                    if (dist < 28 && dist < minDistance) {
                      minDistance = dist;
                      hitIndex = i;
                    }
                  }
                  if (hitIndex != null) {
                    _saveToHistory();
                    setState(() {
                      _activeHandleIndex = hitIndex;
                    });
                  }
                },
                onPanUpdate: (details) {
                  if (_activeHandleIndex == null) return;
                  final pos = details.localPosition;

                  // Clamp to display bounds
                  final cx = (pos.dx - offsetX).clamp(0.0, displayedWidth);
                  final cy = (pos.dy - offsetY).clamp(0.0, displayedHeight);

                  setState(() {
                    _corners[_activeHandleIndex!] = Offset(
                      cx / scale,
                      cy / scale,
                    );
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _activeHandleIndex = null;
                  });
                },
                onPanCancel: () {
                  setState(() {
                    _activeHandleIndex = null;
                  });
                },
              ),
            ),

            // Visual handle circles
            ...List.generate(screenPoints.length, (index) {
              final pt = screenPoints[index];
              final isDragging = _activeHandleIndex == index;
              return Positioned(
                left: pt.dx - 22,
                top: pt.dy - 22,
                child: IgnorePointer(
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      width: isDragging ? 24 : 16,
                      height: isDragging ? 24 : 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.accentColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Magnifier overlay (top center)
            if (activeHandleRelative != null)
              Positioned(
                top: 40,
                left: constraints.maxWidth / 2 - 60,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        Positioned(
                          left: 60 - activeHandleRelative.dx * 3.0,
                          top: 60 - activeHandleRelative.dy * 3.0,
                          width: displayedWidth * 3.0,
                          height: displayedHeight * 3.0,
                          child: Image.file(
                            File(widget.originalImagePath),
                            fit: BoxFit.fill,
                          ),
                        ),
                        // Center crosshair
                        Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Floating control buttons at the bottom
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Reset / Undo group
                    Row(
                      children: [
                        IconButton(
                          tooltip: l10n.docScanCropUndo,
                          icon: const Icon(Icons.undo, color: Colors.white),
                          onPressed: _history.isNotEmpty ? _undo : null,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: l10n.docScanCropReset,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _reset,
                        ),
                      ],
                    ),

                    // Cancel / Apply group
                    Row(
                      children: [
                        TextButton(
                          onPressed: widget.onCancel,
                          child: Text(
                            l10n.docScanCropCancel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => widget.onApply(_corners),
                          icon: const Icon(Icons.check),
                          label: Text(l10n.docScanCropApply),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PolygonPainter extends CustomPainter {
  final List<Offset> points;
  final Color accentColor;

  const _PolygonPainter({required this.points, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 4) return;

    final paintLine = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final paintFill = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accentColor != accentColor;
  }
}
