import 'dart:math' as math;
import 'package:flutter/widgets.dart';
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

enum DeviceScreenOrientation {
  portraitUp,
  portraitDown,
  landscapeLeft,
  landscapeRight,
}

class BubbleLevelSensor {
  double _smoothPitch = 0;
  double _smoothRoll = 0;
  CalibrationOffset _offset = const CalibrationOffset();
  DeviceScreenOrientation _orientation = DeviceScreenOrientation.portraitUp;
  Orientation _uiOrientation = Orientation.portrait;

  static const double _alpha = 0.22;

  DeviceScreenOrientation get orientation => _orientation;

  void setUiOrientation(Orientation orientation) {
    _uiOrientation = orientation;
  }

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
    // Use a threshold of 7.0 to prevent orientation switching during normal tilts.
    if (_uiOrientation == Orientation.portrait) {
      if (_orientation != DeviceScreenOrientation.portraitUp &&
          _orientation != DeviceScreenOrientation.portraitDown) {
        _orientation = DeviceScreenOrientation.portraitUp;
      }
      if (event.y > 7.0) {
        _orientation = DeviceScreenOrientation.portraitUp;
      } else if (event.y < -7.0) {
        _orientation = DeviceScreenOrientation.portraitDown;
      }
    } else {
      if (_orientation != DeviceScreenOrientation.landscapeLeft &&
          _orientation != DeviceScreenOrientation.landscapeRight) {
        _orientation = DeviceScreenOrientation.landscapeLeft;
      }
      if (event.x > 7.0) {
        _orientation = DeviceScreenOrientation.landscapeLeft;
      } else if (event.x < -7.0) {
        _orientation = DeviceScreenOrientation.landscapeRight;
      }
    }

    double mappedX = event.x;
    double mappedY = event.y;
    double mappedZ = event.z;

    switch (_orientation) {
      case DeviceScreenOrientation.portraitUp:
        mappedX = event.x;
        mappedY = event.y;
        break;
      case DeviceScreenOrientation.portraitDown:
        mappedX = -event.x;
        mappedY = -event.y;
        break;
      case DeviceScreenOrientation.landscapeLeft:
        mappedX = -event.y;
        mappedY = event.x;
        break;
      case DeviceScreenOrientation.landscapeRight:
        mappedX = event.y;
        mappedY = -event.x;
        break;
    }

    final rawPitch = _pitchFromAccel(mappedX, mappedY, mappedZ);
    final rawRoll = _rollFromAccel(mappedX, mappedY, mappedZ);

    final correctedPitch = rawPitch - _offset.pitch;
    final correctedRoll = rawRoll - _offset.roll;

    _smoothPitch += (correctedPitch - _smoothPitch) * _alpha;
    _smoothRoll += (correctedRoll - _smoothRoll) * _alpha;

    return OrientationReading(pitch: _smoothPitch, roll: _smoothRoll);
  }

  static double _pitchFromAccel(double x, double y, double z) {
    return math.atan2(y, math.sqrt(x * x + z * z)) * 180 / math.pi;
  }

  static double _rollFromAccel(double x, double y, double z) {
    return math.atan2(-x, math.sqrt(y * y + z * z)) * 180 / math.pi;
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
