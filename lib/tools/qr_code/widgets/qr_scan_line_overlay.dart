import 'package:flutter/material.dart';

/// Animated viewfinder drawn on top of the camera preview: a centered square
/// reticle with corner brackets and a sweeping scan line.
class QrScanLineOverlay extends StatefulWidget {
  final Color accentColor;

  const QrScanLineOverlay({super.key, required this.accentColor});

  @override
  State<QrScanLineOverlay> createState() => _QrScanLineOverlayState();
}

class _QrScanLineOverlayState extends State<QrScanLineOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = (constraints.biggest.shortestSide * 0.7).clamp(
            160.0,
            320.0,
          );
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ReticlePainter(
                    accent: widget.accentColor,
                    progress: _controller.value,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color accent;
  final double progress;

  _ReticlePainter({required this.accent, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 28.0;
    const radius = 16.0;
    final bracket = Paint()
      ..color = accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;

    // Four rounded corner brackets.
    void corner(Offset c, double hx, double hy) {
      final path = Path()
        ..moveTo(c.dx + hx * (cornerLen), c.dy)
        ..lineTo(c.dx + hx * radius, c.dy)
        ..arcToPoint(
          Offset(c.dx, c.dy + hy * radius),
          radius: const Radius.circular(radius),
          clockwise: hx * hy < 0,
        )
        ..lineTo(c.dx, c.dy + hy * cornerLen);
      canvas.drawPath(path, bracket);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomRight, -1, -1);
    corner(rect.bottomLeft, 1, -1);

    // Sweeping scan line with a soft glow gradient.
    final y = size.height * progress;
    final lineRect = Rect.fromLTWH(8, y - 12, size.width - 16, 24);
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: 0.45),
          accent.withValues(alpha: 0),
        ],
      ).createShader(lineRect);
    canvas.drawRect(lineRect, glow);

    final line = Paint()
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), line);
  }

  @override
  bool shouldRepaint(_ReticlePainter old) =>
      old.progress != progress || old.accent != accent;
}
