import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class OrientationReading {
  final double pitch;
  final double roll;

  const OrientationReading({required this.pitch, required this.roll});

  @override
  String toString() =>
      'pitch=${pitch.toStringAsFixed(1)} roll=${roll.toStringAsFixed(1)}';
}

class CalibrationOffset {
  final double pitch;
  final double roll;

  const CalibrationOffset({this.pitch = 0, this.roll = 0});
}

class BubbleLevelSensor {
  double _smoothPitch = 0;
  double _smoothRoll = 0;
  CalibrationOffset _offset = const CalibrationOffset();

  static const double _alpha = 0.22;

  void calibrateZero(OrientationReading reading) {
    _offset = CalibrationOffset(
      pitch: _offset.pitch + reading.pitch,
      roll: _offset.roll + reading.roll,
    );
    _smoothPitch = 0;
    _smoothRoll = 0;
  }

  void resetCalibration() {
    _offset = const CalibrationOffset();
  }

  CalibrationOffset get offset => _offset;

  OrientationReading get currentReading =>
      OrientationReading(pitch: _smoothPitch, roll: _smoothRoll);

  OrientationReading process(AccelerometerEvent event) {
    final rawPitch = _pitchFromAccel(event.x, event.y, event.z);
    final rawRoll = _rollFromAccel(event.x, event.y, event.z);

    final correctedPitch = rawPitch - _offset.pitch;
    final correctedRoll = rawRoll - _offset.roll;

    _smoothPitch += (correctedPitch - _smoothPitch) * _alpha;
    _smoothRoll += (correctedRoll - _smoothRoll) * _alpha;

    return OrientationReading(pitch: _smoothPitch, roll: _smoothRoll);
  }

  static double _pitchFromAccel(double x, double y, double z) {
    return math.atan2(-x, math.sqrt(y * y + z * z)) * 180 / math.pi;
  }

  static double _rollFromAccel(double x, double y, double z) {
    return math.atan2(y, z) * 180 / math.pi;
  }

  static bool isLevel(double pitch, double roll, double tolerance) {
    return pitch.abs() <= tolerance && roll.abs() <= tolerance;
  }

  static double clamp(double value, double min, double max) {
    return math.min(max, math.max(min, value));
  }

  static double roundToOne(double value) {
    return (value * 10).roundToDouble() / 10;
  }
}
