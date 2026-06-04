import 'package:flutter/material.dart';

class BubbleLevelView1d extends StatelessWidget {
  final double normalizedRoll;
  final bool locked;
  final Color accentColor;

  const BubbleLevelView1d({
    super.key,
    required this.normalizedRoll,
    required this.locked,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final trackH = (h * 0.18).clamp(40.0, 72.0);
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: trackH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(trackH / 2),
              child: CustomPaint(
                painter: _BeamPainter(
                  normalizedRoll: normalizedRoll,
                  locked: locked,
                  accentColor: accentColor,
                  theme: theme,
                ),
                size: Size(constraints.maxWidth, trackH),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double normalizedRoll;
  final bool locked;
  final Color accentColor;
  final ThemeData theme;

  _BeamPainter({
    required this.normalizedRoll,
    required this.locked,
    required this.accentColor,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final isDark = theme.brightness == Brightness.dark;
    final trackRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final r = size.height / 2;
    final rrect = RRect.fromRectAndRadius(trackRect, Radius.circular(r));
    final cx = size.width / 2;

    if (isDark) {
      final surface = theme.colorScheme.surface;
      Color on(Color c, double opacity) =>
          Color.alphaBlend(c.withValues(alpha: opacity), surface);
      canvas.drawRRect(rrect, Paint()..color = on(accentColor, 0.15));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [on(accentColor, 0.10), on(accentColor, 0.05)],
          ).createShader(trackRect),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final hw = size.width * 0.08;
      canvas.drawRect(
        Rect.fromLTWH(cx - hw, 0, hw * 2, size.height),
        Paint()..color = accentColor.withValues(alpha: 0.25),
      );
      final linePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.4)
        ..strokeWidth = 1;
      for (final x in [cx - hw, cx + hw]) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    } else {
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFFE0E0E0));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFBDBDBD), const Color(0xFFE0E0E0)],
          ).createShader(trackRect),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFF757575)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final hw = size.width * 0.08;
      canvas.drawRect(
        Rect.fromLTWH(cx - hw, 0, hw * 2, size.height),
        Paint()..color = accentColor.withValues(alpha: 0.35),
      );
      final linePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.55)
        ..strokeWidth = 1;
      for (final x in [cx - hw, cx + hw]) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }

    final bubbleX = normalizedRoll.clamp(-1.0, 1.0) * (size.width / 2 - r - 8);
    final bw = (size.height * 0.85).clamp(32.0, 56.0);
    final bh = size.height * 0.6;
    final bx = (cx + bubbleX - bw / 2).clamp(0.0, size.width - bw);
    final by = (size.height - bh) / 2;
    final bubbleRect = Rect.fromLTWH(bx, by, bw, bh);

    if (isDark) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, Radius.circular(bh / 2)),
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 1,
            colors: [
              accentColor.withValues(alpha: 0.9),
              accentColor.withValues(alpha: 0.7),
              accentColor.withValues(alpha: 0.5),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(bubbleRect),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, Radius.circular(bh / 2)),
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 1,
            colors: const [
              Color(0xFF1565C0),
              Color(0xFF0D47A1),
              Color(0xFF0A2E6E),
            ],
            stops: [0, 0.5, 1],
          ).createShader(bubbleRect),
      );
    }

    if (locked) {
      const lockedColor = Color(0xFF1B5E20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, Radius.circular(bh / 2)),
        Paint()
          ..color = lockedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx - 3, by - 3, bw + 6, bh + 6),
          Radius.circular((bh + 6) / 2),
        ),
        Paint()
          ..color = lockedColor.withValues(alpha: isDark ? 0.3 : 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, Radius.circular(bh / 2)),
        Paint()
          ..color = isDark
              ? Colors.white.withValues(alpha: 0.8)
              : const Color(0xFF1565C0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.normalizedRoll != normalizedRoll ||
      old.locked != locked ||
      old.theme != theme;
}
