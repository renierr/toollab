import 'dart:async';
import 'package:flutter/material.dart';
import 'emf_reading.dart';
import 'sensor_service.dart';
import 'audio_service.dart';

class DetectorState extends ChangeNotifier {
  final SensorService _sensorService = SensorService();
  final AudioService _audioService = AudioService();
  StreamSubscription<EmfReading>? _emfSubscription;

  // Active state
  bool _isScanning = false;
  EmfReading? _currentReading;
  final List<double> _history = [];
  static const int historyLimit = 80;

  // Baseline calibration values
  double _baselineX = 0.0;
  double _baselineY = 0.0;
  double _baselineZ = 0.0;

  // Alert and feedback settings
  double _warningThreshold = 45.0; // Default threshold in uT
  bool _soundEnabled = true;

  // Low-pass filter smoothing coefficient (alpha)
  static const double _smoothingFactor = 0.22;

  // Track if physical sensor actually produced any signal
  bool _hasPhysicalSignal = false;
  Timer? _initialSignalTimeout;

  DetectorState() {
    // Start listening to the stream
    _emfSubscription = _sensorService.emfStream.listen(_onNewReading);

    // Auto-detect if physical magnetometer is missing or silent.
    // If we get no signals within 1.5 seconds, we assume we are in an emulator/Windows
    // and automatically enable simulated mode so the app is fully interactable.
    _initialSignalTimeout = Timer(const Duration(milliseconds: 1500), () {
      if (!_hasPhysicalSignal) {
        debugPrint(
          '[DetectorState] No physical magnetometer signal detected. Activating simulator.',
        );
        setSimulationMode(true);
        setSimulationPreset(SimulationPreset.ambientNoise);
      }
    });
  }

  // Getters
  bool get isScanning => _isScanning;
  EmfReading? get currentReading => _currentReading;
  List<double> get history => _history;

  double get baselineX => _baselineX;
  double get baselineY => _baselineY;
  double get baselineZ => _baselineZ;
  bool get isCalibrated =>
      _baselineX != 0.0 || _baselineY != 0.0 || _baselineZ != 0.0;

  double get warningThreshold => _warningThreshold;
  bool get soundEnabled => _soundEnabled;

  bool get isSimulationActive => _sensorService.isSimulationActive;
  SimulationPreset get currentPreset => _sensorService.currentPreset;

  /// Toggles the sensor scanning on/off.
  void toggleScanning() {
    _isScanning = !_isScanning;

    if (!_isScanning) {
      // Pause beeper if scanning stops
      _audioService.setEnabled(false);
    } else {
      _audioService.setEnabled(_soundEnabled);
    }

    notifyListeners();
  }

  /// Sets baseline offset based on the current electromagnetic environment.
  void calibrateBaseline() {
    if (_currentReading == null) return;

    _baselineX = _currentReading!.x;
    _baselineY = _currentReading!.y;
    _baselineZ = _currentReading!.z;

    _sensorService.setBaseline(_baselineX, _baselineY, _baselineZ);

    // Apply immediately to current reading to avoid UI jumpiness
    if (_currentReading != null) {
      _currentReading = _currentReading!.withBaseline(
        _baselineX,
        _baselineY,
        _baselineZ,
      );
    }

    notifyListeners();
  }

  /// Clears any calibrated zero offsets.
  void resetBaseline() {
    _baselineX = 0.0;
    _baselineY = 0.0;
    _baselineZ = 0.0;

    _sensorService.resetBaseline();

    if (_currentReading != null) {
      _currentReading = _currentReading!.withBaseline(0.0, 0.0, 0.0);
    }

    notifyListeners();
  }

  /// Updates the threshold value that triggers alerts.
  void setWarningThreshold(double value) {
    _warningThreshold = value;
    notifyListeners();
  }

  /// Toggles acoustic Geiger-ticking feedback.
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    _audioService.setEnabled(_isScanning && _soundEnabled);
    notifyListeners();
  }

  /// Switches between physical hardware stream and virtual mock generator.
  void setSimulationMode(bool enable) {
    _sensorService.setSimulationMode(enable);
    notifyListeners();
  }

  /// Sets simulation presets (AC Mains Wire, Permanent Magnet, Ambient Drift).
  void setSimulationPreset(SimulationPreset preset) {
    _sensorService.setSimulationPreset(preset);
    notifyListeners();
  }

  /// Updates manual coordinates in mock slider mode.
  void setManualSimulationValues(double x, double y, double z) {
    _sensorService.setManualSimulationValues(x, y, z);
  }

  void _onNewReading(EmfReading rawReading) {
    _hasPhysicalSignal = true;
    _initialSignalTimeout?.cancel();

    if (!_isScanning) {
      // Still update the current reading (visual display of idle state),
      // but do not add to history or play sounds.
      _currentReading = rawReading;
      notifyListeners();
      return;
    }

    // Apply Low-pass filtering to smoothen jitter
    double smoothedX, smoothedY, smoothedZ;
    if (_currentReading == null) {
      smoothedX = rawReading.x;
      smoothedY = rawReading.y;
      smoothedZ = rawReading.z;
    } else {
      smoothedX =
          _currentReading!.x +
          _smoothingFactor * (rawReading.x - _currentReading!.x);
      smoothedY =
          _currentReading!.y +
          _smoothingFactor * (rawReading.y - _currentReading!.y);
      smoothedZ =
          _currentReading!.z +
          _smoothingFactor * (rawReading.z - _currentReading!.z);
    }

    _currentReading = EmfReading.fromRaw(
      smoothedX,
      smoothedY,
      smoothedZ,
      baselineX: _baselineX,
      baselineY: _baselineY,
      baselineZ: _baselineZ,
    );

    // Save delta magnitude in history for scrolling oscilloscope chart
    _history.add(_currentReading!.deltaMagnitude);
    if (_history.length > historyLimit) {
      _history.removeAt(0);
    }

    // Trigger acoustic beeper ticks speed based on strength
    if (_soundEnabled) {
      _audioService.updateSignalStrength(
        _currentReading!.deltaMagnitude,
        _warningThreshold,
      );
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _initialSignalTimeout?.cancel();
    _emfSubscription?.cancel();
    _sensorService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
