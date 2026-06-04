import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'emf_reading.dart';

enum SimulationPreset {
  none,
  mainsCable, // Simulated AC electrical current (oscillating fields)
  strongMagnet, // High DC magnetic field offset
  ambientNoise, // Normal fluctuating environmental fields
}

class SensorService {
  final _streamController = StreamController<EmfReading>.broadcast();
  StreamSubscription<MagnetometerEvent>? _sensorSubscription;
  Timer? _simulationTimer;
  final Random _random = Random();
  double _time = 0.0;

  // Calibration Offsets (Baseline)
  double _baselineX = 0.0;
  double _baselineY = 0.0;
  double _baselineZ = 0.0;

  // Simulation Parameters
  bool _useSimulation = false;
  SimulationPreset _currentPreset = SimulationPreset.none;
  final double _simBaseX = 40.0; // Earth's baseline
  final double _simBaseY = -15.0;
  final double _simBaseZ = -20.0;

  // Custom manual slider inputs
  double _manualSliderX = 0.0;
  double _manualSliderY = 0.0;
  double _manualSliderZ = 0.0;
  bool _useManualSliders = false;

  /// Returns true if the active platform has magnetometer hardware support.
  /// Web and desktop platforms (Windows, macOS, Linux) do not support physical magnetometers in Flutter.
  static bool get isHardwareSupported {
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

  SensorService() {
    if (!isHardwareSupported) {
      _useSimulation = true;
      _currentPreset = SimulationPreset.ambientNoise;
      _startSimulationStream();
    } else {
      _startSensorStream();
    }
  }

  Stream<EmfReading> get emfStream => _streamController.stream;

  bool get isSimulationActive => _useSimulation;

  SimulationPreset get currentPreset => _currentPreset;

  /// Updates baseline offsets for calibration.
  void setBaseline(double x, double y, double z) {
    _baselineX = x;
    _baselineY = y;
    _baselineZ = z;
  }

  /// Reset baseline offsets.
  void resetBaseline() {
    _baselineX = 0.0;
    _baselineY = 0.0;
    _baselineZ = 0.0;
  }

  /// Enable or disable simulation mode.
  void setSimulationMode(bool enable) {
    if (!isHardwareSupported) {
      // Hardware sensors are not supported on this platform. Force simulation mode.
      _useSimulation = true;
      if (_simulationTimer == null) {
        _startSimulationStream();
      }
      return;
    }

    if (_useSimulation == enable) return;
    _useSimulation = enable;

    if (_useSimulation) {
      _sensorSubscription?.cancel();
      _sensorSubscription = null;
      _startSimulationStream();
    } else {
      _simulationTimer?.cancel();
      _simulationTimer = null;
      _startSensorStream();
    }
  }

  /// Sets a specific predefined simulation preset.
  void setSimulationPreset(SimulationPreset preset) {
    _currentPreset = preset;
    _useManualSliders = false;
  }

  /// Manually adjusts simulated coordinates via sliders.
  void setManualSimulationValues(double x, double y, double z) {
    _useManualSliders = true;
    _manualSliderX = x;
    _manualSliderY = y;
    _manualSliderZ = z;
  }

  void _startSensorStream() {
    _sensorSubscription?.cancel();

    try {
      _sensorSubscription = magnetometerEventStream().listen(
        (MagnetometerEvent event) {
          if (!_useSimulation) {
            // Apply standard low-pass smoothing (exponential moving average) or pass raw
            // We'll perform smoothing at the state manager level to keep readings clean.
            final reading = EmfReading.fromRaw(
              event.x,
              event.y,
              event.z,
              baselineX: _baselineX,
              baselineY: _baselineY,
              baselineZ: _baselineZ,
            );
            _streamController.add(reading);
          }
        },
        onError: (error) {
          debugPrint(
            '[SensorService] Magnetometer error: $error. Falling back to simulation.',
          );
          setSimulationMode(true);
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint(
        '[SensorService] Magnetometer exception: $e. Falling back to simulation.',
      );
      setSimulationMode(true);
    }
  }

  void _startSimulationStream() {
    _simulationTimer?.cancel();
    // Simulate events at ~30Hz (every 33 milliseconds)
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 33), (
      timer,
    ) {
      if (!_useSimulation) return;

      _time += 0.033;
      double rx = 0.0;
      double ry = 0.0;
      double rz = 0.0;

      // Add high frequency jitter (natural electromagnetic noise of ~0.5 - 1.5 uT)
      final noiseX = (_random.nextDouble() - 0.5) * 1.2;
      final noiseY = (_random.nextDouble() - 0.5) * 1.2;
      final noiseZ = (_random.nextDouble() - 0.5) * 1.2;

      if (_useManualSliders) {
        rx = _manualSliderX + noiseX;
        ry = _manualSliderY + noiseY;
        rz = _manualSliderZ + noiseZ;
      } else {
        // Base ambient Earth magnetic field
        rx = _simBaseX + noiseX;
        ry = _simBaseY + noiseY;
        rz = _simBaseZ + noiseZ;

        switch (_currentPreset) {
          case SimulationPreset.mainsCable:
            // Simulate 50/60 Hz AC current.
            // Magnetic field oscillates rapidly. Since we sample at 30Hz,
            // we'll get an aliased but highly dynamic sine wave peak.
            // Let's create an alternating magnetic field overlay.
            final acWave = 85.0 * sin(_time * 12.0); // Large oscillation
            rx += acWave;
            ry += acWave * 0.5;
            rz += acWave * 0.2;
            break;

          case SimulationPreset.strongMagnet:
            // Simulate proximity of a permanent neodymium magnet (large DC offset)
            rx += 180.0;
            ry += -80.0;
            rz += 120.0;
            break;

          case SimulationPreset.ambientNoise:
            // Dynamic moving drift (simulating walking past electrical boxes)
            rx += sin(_time * 0.5) * 15.0;
            ry += cos(_time * 0.3) * 10.0;
            rz += sin(_time * 0.2) * 8.0;
            break;

          case SimulationPreset.none:
            // Just standard ambient Earth magnetism
            break;
        }
      }

      final reading = EmfReading.fromRaw(
        rx,
        ry,
        rz,
        baselineX: _baselineX,
        baselineY: _baselineY,
        baselineZ: _baselineZ,
      );

      _streamController.add(reading);
    });
  }

  void dispose() {
    _sensorSubscription?.cancel();
    _simulationTimer?.cancel();
    _streamController.close();
  }
}
