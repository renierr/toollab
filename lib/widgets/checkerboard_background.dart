import 'package:flutter/material.dart';

/// A two-tone checkerboard fill used to signal transparency behind an image.
class CheckerboardBackground extends StatelessWidget {
  final Widget? child;
  final double cell;

  const CheckerboardBackground({super.key, this.child, this.cell = 12});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _CheckerboardPainter(
        even: scheme.surfaceContainerHighest,
        odd: scheme.surface,
        cell: cell,
      ),
      child: child,
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  final Color even;
  final Color odd;
  final double cell;

  const _CheckerboardPainter({
    required this.even,
    required this.odd,
    required this.cell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = odd);
    final evenPaint = Paint()..color = even;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final isEven = ((x ~/ cell) + (y ~/ cell)) % 2 == 0;
        if (isEven) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), evenPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) =>
      oldDelegate.even != even ||
      oldDelegate.odd != odd ||
      oldDelegate.cell != cell;
}
