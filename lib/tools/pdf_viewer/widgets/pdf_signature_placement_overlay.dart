import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The draggable / resizable signature box shown over a rendered PDF page.
///
/// Pan deltas are reported in device pixels; the parent converts them to page
/// fractions using the displayed page rectangle.
class PdfSignaturePlacementOverlay extends StatelessWidget {
  final Uint8List image;
  final ValueChanged<Offset> onDrag;
  final ValueChanged<Offset> onResize;
  final VoidCallback onRemove;

  const PdfSignaturePlacementOverlay({
    super.key,
    required this.image,
    required this.onDrag,
    required this.onResize,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => onDrag(d.delta),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 1.5),
              ),
              child: Image.memory(image, fit: BoxFit.fill),
            ),
          ),
        ),
        Positioned(
          top: -12,
          right: -12,
          child: _CircleButton(
            icon: Icons.close,
            color: Theme.of(context).colorScheme.error,
            onTap: onRemove,
          ),
        ),
        Positioned(
          right: -10,
          bottom: -10,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => onResize(d.delta),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.open_in_full,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}
