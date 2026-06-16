import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The draggable / resizable / rotatable signature box shown over a rendered
/// PDF page.
///
/// Empty margins are reserved around the box so the handles render fully inside
/// the widget's bounds (a handle placed outside the parent's box would not be
/// hit-testable). Each handle's clickable area equals its visible dot — no
/// oversized invisible target. The rotate handle sits above the box, clear of
/// the drag area, so dragging never triggers a rotation. Drag/resize deltas are
/// reported in device pixels; rotation is an absolute angle in radians
/// (clockwise), tracked relative to the grab point so re-grabbing never snaps.
class PdfSignaturePlacementOverlay extends StatefulWidget {
  static const double sideMargin = 20;
  static const double topMargin = 34;
  static const double _dot = 22;

  final Uint8List image;
  final double rotation;
  final ValueChanged<Offset> onDrag;
  final ValueChanged<Offset> onResize;
  final ValueChanged<double> onRotate;
  final VoidCallback onRemove;

  const PdfSignaturePlacementOverlay({
    super.key,
    required this.image,
    required this.rotation,
    required this.onDrag,
    required this.onResize,
    required this.onRotate,
    required this.onRemove,
  });

  @override
  State<PdfSignaturePlacementOverlay> createState() =>
      _PdfSignaturePlacementOverlayState();
}

class _PdfSignaturePlacementOverlayState
    extends State<PdfSignaturePlacementOverlay> {
  final GlobalKey _boxKey = GlobalKey();
  double _startPointerAngle = 0;
  double _startRotation = 0;

  double _pointerAngle(Offset globalPointer) {
    final box = _boxKey.currentContext!.findRenderObject() as RenderBox;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final v = globalPointer - center;
    return math.atan2(v.dy, v.dx);
  }

  void _rotateStart(Offset g) {
    _startPointerAngle = _pointerAngle(g);
    _startRotation = widget.rotation;
  }

  void _rotateUpdate(Offset g) {
    widget.onRotate(_startRotation + (_pointerAngle(g) - _startPointerAngle));
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    const side = PdfSignaturePlacementOverlay.sideMargin;
    const top = PdfSignaturePlacementOverlay.topMargin;
    const dot = PdfSignaturePlacementOverlay._dot;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Signature box + drag handler.
        Padding(
          padding: const EdgeInsets.only(
            left: side,
            right: side,
            top: top,
            bottom: side,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => widget.onDrag(d.delta),
            child: Container(
              key: _boxKey,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.5),
              ),
              child: Transform.rotate(
                angle: widget.rotation,
                child: Image.memory(widget.image, fit: BoxFit.fill),
              ),
            ),
          ),
        ),
        // Rotate handle, fully above the box (clear of the drag area).
        Positioned(
          top: top - dot,
          left: 0,
          right: 0,
          child: Center(
            child: _Handle(
              icon: Icons.rotate_right,
              color: color,
              onPanStart: (d) => _rotateStart(d.globalPosition),
              onPanUpdate: (d) => _rotateUpdate(d.globalPosition),
            ),
          ),
        ),
        // Delete handle (top-right corner of the box).
        Positioned(
          top: top - dot / 2,
          right: side - dot / 2,
          child: _Handle(
            icon: Icons.close,
            color: Theme.of(context).colorScheme.error,
            onTap: widget.onRemove,
          ),
        ),
        // Resize handle (bottom-right corner of the box).
        Positioned(
          bottom: side - dot / 2,
          right: side - dot / 2,
          child: _Handle(
            icon: Icons.open_in_full,
            color: color,
            onPanUpdate: (d) => widget.onResize(d.delta),
          ),
        ),
      ],
    );
  }
}

/// A handle whose clickable area equals its visible dot.
class _Handle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;

  const _Handle({
    required this.icon,
    required this.color,
    this.onTap,
    this.onPanStart,
    this.onPanUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: PdfSignaturePlacementOverlay._dot,
        height: PdfSignaturePlacementOverlay._dot,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
    );
  }
}
