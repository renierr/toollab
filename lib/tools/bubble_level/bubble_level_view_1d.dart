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
    return SizedBox(
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: CustomPaint(
          painter: _BeamPainter(
            normalizedRoll: normalizedRoll,
            locked: locked,
            accentColor: accentColor,
          ),
        ),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double normalizedRoll;
  final bool locked;
  final Color accentColor;

  _BeamPainter({
    required this.normalizedRoll,
    required this.locked,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(28),
    );

    final bgPaint = Paint()..color = accentColor.withAlpha(12);
    canvas.drawRRect(rrect, bgPaint);

    final trackPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accentColor.withAlpha(28), accentColor.withAlpha(14)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rrect, trackPaint);

    final borderPaint = Paint()
      ..color = accentColor.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(rrect, borderPaint);

    final cx = size.width / 2;
    final centerZoneW = size.width * 0.16;
    final centerPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accentColor.withAlpha(50), accentColor.withAlpha(20)],
          ).createShader(
            Rect.fromLTWH(cx - centerZoneW / 2, 0, centerZoneW, size.height),
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - centerZoneW / 2, 0, centerZoneW, size.height),
        const Radius.circular(0),
      ),
      centerPaint,
    );

    final centerLinePaint = Paint()
      ..color = accentColor.withAlpha(60)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(cx - centerZoneW / 2, 0),
      Offset(cx - centerZoneW / 2, size.height),
      centerLinePaint,
    );
    canvas.drawLine(
      Offset(cx + centerZoneW / 2, 0),
      Offset(cx + centerZoneW / 2, size.height),
      centerLinePaint,
    );

    final bubbleX = _clamp(normalizedRoll, -1, 1) * (size.width / 2 - 28 - 8);
    final bw = 52.0;
    final bh = size.height * 0.7;
    final bx = cx + bubbleX - bw / 2;
    final by = (size.height - bh) / 2;

    final bubblePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1,
        colors: [
          const Color(0xFFFBFFD8),
          const Color(0xFFB7FF70),
          const Color(0xFF57CF39),
          if (locked) const Color(0xFF309A29) else Color(0xFF888888),
        ],
        stops: const [0, 0.42, 0.72, 1],
      ).createShader(Rect.fromLTWH(bx, by, bw, bh));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        Radius.circular(bh / 2),
      ),
      bubblePaint,
    );

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = locked
          ? const Color(0xFFA4FF80).withAlpha(140)
          : Color(0xFF7EFF57).withAlpha(80);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh * 0.6),
        Radius.circular(bh / 2),
      ),
      glowPaint,
    );
  }

  double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.normalizedRoll != normalizedRoll || old.locked != locked;
}
