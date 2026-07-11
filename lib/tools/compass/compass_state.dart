import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum CompassInterferenceStatus { normal, warning }

class CompassState extends ChangeNotifier {
  // Constants for exponential moving average (smoothing)
  static const double _alpha = 0.15; // Jitter filter factor

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magnetSub;

  // Sensor state variables
  double _heading = 0.0;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _magneticFieldStrength = 45.0; // Default ambient field in microteslas
  bool _useSimulation = false;
  bool _isHardwareSupported = true;

  // Raw readings
  double _ax = 0.0;
  double _ay = 0.0;
  double _az = 9.81;

  double _mx = 0.0;
  double _my = 0.0;
  double _mz = 0.0;

  // Dynamic trigonometric smoothing states to prevent 0/360 wrap-around spinning
  double _smoothSin = 0.0;
  double _smoothCos = 1.0;

  // Simulation parameters
  double _simHeading = 0.0;

  CompassState() {
    _isHardwareSupported = _checkHardwareSupport();
    if (!_isHardwareSupported) {
      _useSimulation = true;
    } else {
      _startSensorStreams();
    }
  }

  // Getters
  double get heading => _useSimulation ? _simHeading : _heading;
  double get pitch => _useSimulation ? 0.0 : _pitch;
  double get roll => _useSimulation ? 0.0 : _roll;
  double get magneticFieldStrength =>
      _useSimulation ? 45.0 : _magneticFieldStrength;
  bool get useSimulation => _useSimulation;
  bool get isHardwareSupported => _isHardwareSupported;

  CompassInterferenceStatus get interferenceStatus {
    if (_useSimulation) return CompassInterferenceStatus.normal;
    // Ambient magnetic field is usually 30 to 60 uT.
    // We flag interference if it's extremely low (< 22 uT) or extremely high (> 90 uT).
    if (_magneticFieldStrength < 22.0 || _magneticFieldStrength > 90.0) {
      return CompassInterferenceStatus.warning;
    }
    return CompassInterferenceStatus.normal;
  }

  /// Sets simulation mode.
  void toggleSimulation(bool enabled) {
    if (!_isHardwareSupported) {
      _useSimulation = true; // Force simulation if hardware is not available
      return;
    }
    if (_useSimulation == enabled) return;
    _useSimulation = enabled;

    if (_useSimulation) {
      _stopSensorStreams();
    } else {
      _startSensorStreams();
    }
    notifyListeners();
  }

  /// Allows manual adjustment of heading in simulation mode (e.g. by dragging).
  void adjustSimulatedHeading(double deltaDegrees) {
    if (!_useSimulation) return;
    _simHeading = (_simHeading + deltaDegrees + 360) % 360;
    notifyListeners();
  }

  bool _checkHardwareSupport() {
    if (kIsWeb) return false;
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  void _startSensorStreams() {
    _stopSensorStreams();

    try {
      _accelSub =
          accelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 40),
          ).listen(
            (AccelerometerEvent event) {
              _ax = _ax + (event.x - _ax) * _alpha;
              _ay = _ay + (event.y - _ay) * _alpha;
              _az = _az + (event.z - _az) * _alpha;
              _computeHeading();
            },
            onError: (err) {
              debugPrint('[CompassState] Accelerometer error: $err');
            },
          );

      _magnetSub =
          magnetometerEventStream(
            samplingPeriod: const Duration(milliseconds: 40),
          ).listen(
            (MagnetometerEvent event) {
              _mx = _mx + (event.x - _mx) * _alpha;
              _my = _my + (event.y - _my) * _alpha;
              _mz = _mz + (event.z - _mz) * _alpha;
              _computeHeading();
            },
            onError: (err) {
              debugPrint('[CompassState] Magnetometer error: $err');
              toggleSimulation(true);
            },
          );
    } catch (e) {
      debugPrint('[CompassState] Sensor init failed: $e');
      _isHardwareSupported = false;
      _useSimulation = true;
    }
  }

  void _stopSensorStreams() {
    _accelSub?.cancel();
    _accelSub = null;
    _magnetSub?.cancel();
    _magnetSub = null;
  }

  void _computeHeading() {
    // Calculate total magnetic field strength (magnitude)
    _magneticFieldStrength = math.sqrt(_mx * _mx + _my * _my + _mz * _mz);

    // Normalize accelerometer vector
    final double normA = math.sqrt(_ax * _ax + _ay * _ay + _az * _az);
    if (normA == 0) return;
    final double axN = _ax / normA;
    final double ayN = _ay / normA;
    final double azN = _az / normA;

    // Calculate Pitch (phi) and Roll (theta)
    final double pitch = math.atan2(ayN, azN);
    final double roll = math.atan2(
      -axN,
      ayN * math.sin(pitch) + azN * math.cos(pitch),
    );

    // Smooth pitch/roll for parallax transitions
    _pitch = _pitch + (pitch - _pitch) * _alpha;
    _roll = _roll + (roll - _roll) * _alpha;

    // Apply tilt-compensation to magnetometer vector
    final double sinP = math.sin(pitch);
    final double cosP = math.cos(pitch);
    final double sinR = math.sin(roll);
    final double cosR = math.cos(roll);

    final double xh = _mx * cosR + _my * sinR * sinP + _mz * cosR * sinP;
    final double yh = _my * cosP - _mz * sinP;

    // Azimuth calculation
    final double headingRad = math.atan2(-yh, xh);

    // Apply angular averaging to prevent wrap-around snapping at 0/360 boundary
    _smoothSin = _smoothSin + (math.sin(headingRad) - _smoothSin) * _alpha;
    _smoothCos = _smoothCos + (math.cos(headingRad) - _smoothCos) * _alpha;

    final double smoothedRad = math.atan2(_smoothSin, _smoothCos);
    _heading = (smoothedRad * 180 / math.pi + 360) % 360;

    notifyListeners();
  }

  @override
  void dispose() {
    _stopSensorStreams();
    super.dispose();
  }
}
