import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

class ImageViewerDisplay extends StatefulWidget {
  final ui.Image image;
  final Uint8List? rawBytes;
  final bool isAnimated;
  final TransformationController transformationController;
  final VoidCallback onResetZoom;
  final bool showSiblingNav;
  final bool hasPrevSibling;
  final bool hasNextSibling;
  final String? siblingLabel;
  final VoidCallback? onPrevImage;
  final VoidCallback? onNextImage;

  const ImageViewerDisplay({
    super.key,
    required this.image,
    this.rawBytes,
    this.isAnimated = false,
    required this.transformationController,
    required this.onResetZoom,
    this.showSiblingNav = false,
    this.hasPrevSibling = false,
    this.hasNextSibling = false,
    this.siblingLabel,
    this.onPrevImage,
    this.onNextImage,
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

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!widget.showSiblingNav || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        widget.hasPrevSibling) {
      widget.onPrevImage?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        widget.hasNextSibling) {
      widget.onNextImage?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _zoomBy(double factor) {
    final size = context.size;
    if (size == null) return;
    final current = widget.transformationController.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(0.1, 10.0);
    final effective = target / current;
    if ((effective - 1.0).abs() < 0.001) return;

    final center = Offset(size.width / 2, size.height / 2);
    final zoom = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(effective, effective, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    widget.transformationController.value =
        zoom * widget.transformationController.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final checkerboardColor1 = theme.colorScheme.surfaceContainerHigh;
    final checkerboardColor2 = theme.colorScheme.surfaceContainerLow;

    return Focus(
      autofocus: widget.showSiblingNav,
      onKeyEvent: _handleKey,
      child: ClipRRect(
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
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: Center(
                  child: widget.isAnimated && widget.rawBytes != null
                      ? Image.memory(widget.rawBytes!, fit: BoxFit.contain)
                      : RawImage(image: widget.image, fit: BoxFit.contain),
                ),
              ),
            ),
            // Floating overlay: Zoom level and Reset Zoom button
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                    _ZoomButton(
                      icon: Icons.zoom_out,
                      tooltip: l10n.imgViewZoomOut,
                      color: theme.colorScheme.primary,
                      onPressed: _zoomScale > 0.1
                          ? () => _zoomBy(1 / 1.25)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(_zoomScale * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ZoomButton(
                      icon: Icons.zoom_in,
                      tooltip: l10n.imgViewZoomIn,
                      color: theme.colorScheme.primary,
                      onPressed: _zoomScale < 10.0 ? () => _zoomBy(1.25) : null,
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
                          l10n.commonReset,
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
            // Sibling navigation: prev/next arrows + position indicator
            if (widget.showSiblingNav) ...[
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SiblingNavButton(
                    icon: Icons.chevron_left,
                    tooltip: l10n.imgViewPreviousImage,
                    onPressed: widget.hasPrevSibling
                        ? widget.onPrevImage
                        : null,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _SiblingNavButton(
                    icon: Icons.chevron_right,
                    tooltip: l10n.imgViewNextImage,
                    onPressed: widget.hasNextSibling
                        ? widget.onNextImage
                        : null,
                  ),
                ),
              ),
              if (widget.siblingLabel != null)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                          Icons.collections_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.siblingLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? color : color.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

class _SiblingNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _SiblingNavButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: enabled ? 0.85 : 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon),
        iconSize: 28,
        tooltip: enabled ? tooltip : null,
        color: theme.colorScheme.onSurface,
        disabledColor: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        onPressed: onPressed,
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
