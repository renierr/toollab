import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class BubbleLevelPage extends StatefulWidget {
  const BubbleLevelPage({super.key});

  @override
  State<BubbleLevelPage> createState() => _BubbleLevelPageState();
}

class _BubbleLevelPageState extends State<BubbleLevelPage> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  double _tiltX = 0;
  double _tiltY = 0;
  double _smoothX = 0;
  double _smoothY = 0;

  @override
  void initState() {
    super.initState();
    _subscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 50),
        ).listen((event) {
          setState(() {
            _tiltX = event.x;
            _tiltY = event.y;
            _smoothX = _smoothX * 0.7 + _tiltX * 0.3;
            _smoothY = _smoothY * 0.7 + _tiltY * 0.3;
          });
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final sphereSize = math.min(size.width, size.height) * 0.55;
    final maxOffset = sphereSize / 2 - 24;

    final bubbleX = (_smoothX / 12.0 * maxOffset).clamp(-maxOffset, maxOffset);
    final bubbleY = (_smoothY / 12.0 * maxOffset).clamp(-maxOffset, maxOffset);

    final angle = math.atan2(_smoothX, _smoothY) * 180 / math.pi;
    final magnitude = math.sqrt(_smoothX * _smoothX + _smoothY * _smoothY);
    final isLevel = magnitude < 1.5;

    return Scaffold(
      appBar: AppBar(title: const Text('Bubble Level')),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLevel ? '✓ Level' : 'Not Level',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isLevel
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: sphereSize,
                height: sphereSize,
                child: CustomPaint(
                  painter: _LevelPainter(
                    bubbleX: bubbleX,
                    bubbleY: bubbleY,
                    isLevel: isLevel,
                    accentColor: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pitch: ${angle.toStringAsFixed(1)}°',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(180),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tilt: ${magnitude.toStringAsFixed(1)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelPainter extends CustomPainter {
  final double bubbleX;
  final double bubbleY;
  final bool isLevel;
  final Color accentColor;

  _LevelPainter({
    required this.bubbleX,
    required this.bubbleY,
    required this.isLevel,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final outerPaint = Paint()
      ..color = accentColor.withAlpha(40)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, outerPaint);

    final borderPaint = Paint()
      ..color = accentColor.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    final crossPaint = Paint()
      ..color = accentColor.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - radius * 0.7, center.dy),
      Offset(center.dx + radius * 0.7, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.7),
      Offset(center.dx, center.dy + radius * 0.7),
      crossPaint,
    );

    if (isLevel) {
      final ringPaint = Paint()
        ..color = accentColor.withAlpha(60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius * 0.15, ringPaint);
    }

    final bubbleRadius = radius * 0.12;
    final bubbleCenter = Offset(center.dx + bubbleX, center.dy + bubbleY);

    final bubblePaint = Paint()
      ..color = isLevel ? accentColor : accentColor.withAlpha(180)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubbleCenter, bubbleRadius, bubblePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(
        bubbleCenter.dx - bubbleRadius * 0.2,
        bubbleCenter.dy - bubbleRadius * 0.2,
      ),
      bubbleRadius * 0.4,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_LevelPainter oldDelegate) =>
      oldDelegate.bubbleX != bubbleX ||
      oldDelegate.bubbleY != bubbleY ||
      oldDelegate.isLevel != isLevel;
}
