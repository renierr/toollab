import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class EmfDetectorPage extends StatefulWidget {
  const EmfDetectorPage({super.key});

  @override
  State<EmfDetectorPage> createState() => _EmfDetectorPageState();
}

class _EmfDetectorPageState extends State<EmfDetectorPage> {
  StreamSubscription<MagnetometerEvent>? _subscription;
  double _fieldX = 0;
  double _fieldY = 0;
  double _fieldZ = 0;
  double _magnitude = 0;
  double _smoothMagnitude = 0;
  double _maxMagnitude = 0;

  @override
  void initState() {
    super.initState();
    _subscription =
        magnetometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen((event) {
          setState(() {
            _fieldX = event.x;
            _fieldY = event.y;
            _fieldZ = event.z;
            _magnitude = math.sqrt(
              event.x * event.x + event.y * event.y + event.z * event.z,
            );
            _smoothMagnitude = _smoothMagnitude * 0.7 + _magnitude * 0.3;
            if (_magnitude > _maxMagnitude) _maxMagnitude = _magnitude;
          });
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _resetMax() {
    setState(() => _maxMagnitude = 0);
  }

  String _describeLevel(double uT) {
    if (uT < 0.5) return 'Very Low';
    if (uT < 2.0) return 'Low';
    if (uT < 10.0) return 'Moderate';
    if (uT < 50.0) return 'High';
    return 'Very High';
  }

  Color _levelColor(double uT, ColorScheme colors) {
    if (uT < 0.5) return colors.primary;
    if (uT < 2.0) return colors.tertiary;
    if (uT < 10.0) return Colors.green;
    if (uT < 50.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final level = _describeLevel(_smoothMagnitude);
    final color = _levelColor(_smoothMagnitude, colors);
    final progress = (_smoothMagnitude / 100.0).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EMF Detector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetMax,
            tooltip: 'Reset max',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                _smoothMagnitude.toStringAsFixed(1),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w200,
                  color: color,
                ),
              ),
              Text(
                'µT',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color.withAlpha(180),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  level,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: colors.surfaceContainerHighest,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0 µT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withAlpha(120),
                    ),
                  ),
                  Text(
                    '100 µT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _axisRow('X', _fieldX, colors),
                    const SizedBox(height: 8),
                    _axisRow('Y', _fieldY, colors),
                    const SizedBox(height: 8),
                    _axisRow('Z', _fieldZ, colors),
                    const Divider(height: 24),
                    _axisRow('Max', _maxMagnitude, colors, bold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _axisRow(
    String label,
    double value,
    ColorScheme colors, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            color: colors.onSurface.withAlpha(180),
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)} µT',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
