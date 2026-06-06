import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';
import 'emf_colors.dart';
import 'emf_reading.dart';
import 'detector_state.dart';
import 'circular_gauge.dart';
import 'oscilloscope_chart.dart';
import 'scanner_header.dart';
import 'cable_detected_banner.dart';
import 'calibration_panel.dart';
import 'vector_readout_card.dart';
import 'oscilloscope_header.dart';
import 'scanner_controls_card.dart';
import 'simulator_lab_card.dart';

class EmfDetectorPage extends StatefulWidget {
  const EmfDetectorPage({super.key});

  @override
  State<EmfDetectorPage> createState() => _EmfDetectorPageState();
}

class _EmfDetectorPageState extends State<EmfDetectorPage>
    with DisposeCleanup<EmfDetectorPage> {
  late final DetectorState _state;
  bool _wakeLockActive = false;
  bool _automaticallyTurnedOnWakelock = false;

  @override
  void initState() {
    super.initState();
    _state = DetectorState();
    onDispose(_state.dispose);
    _checkWakeLock();
    _state.addListener(_onStateChange);
    onDispose(() => _state.removeListener(_onStateChange));
    onDispose(WakelockPlus.disable);
  }

  void _onStateChange() {
    if (!mounted) return;
    if (_state.isScanning && !_wakeLockActive) {
      WakelockPlus.enable();
      setState(() {
        _wakeLockActive = true;
        _automaticallyTurnedOnWakelock = true;
      });
    } else if (!_state.isScanning && _wakeLockActive) {
      if (_automaticallyTurnedOnWakelock) {
        WakelockPlus.disable();
        setState(() {
          _wakeLockActive = false;
          _automaticallyTurnedOnWakelock = false;
        });
      }
    }
  }

  void _checkWakeLock() async {
    final active = await WakelockPlus.enabled;
    if (!mounted) return;
    setState(() {
      _wakeLockActive = active;
    });
  }

  void _toggleWakeLock() async {
    final target = !_wakeLockActive;
    if (target) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
    if (!mounted) return;
    setState(() {
      _wakeLockActive = target;
      _automaticallyTurnedOnWakelock = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolLayout(
      title: 'EMF Detector',
      fullscreen: EmfDetectorTool.config.fullscreen,
      showFloatingBackButton: false,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, child) {
          final current = _state.currentReading ?? EmfReading.fromRaw(0, 0, 0);
          final isWarning =
              _state.isScanning &&
              current.deltaMagnitude >= _state.warningThreshold;

          return Stack(
            children: [
              Positioned(
                top: -150,
                left: -50,
                right: -50,
                height: 350,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.8,
                      colors: isWarning
                          ? [
                              EmfColors.neonPink.withValues(alpha: 0.18),
                              EmfColors.neonPink.withValues(alpha: 0.0),
                            ]
                          : [
                              EmfColors.neonCyan.withValues(alpha: 0.12),
                              EmfColors.neonCyan.withValues(alpha: 0.0),
                            ],
                    ),
                  ),
                ),
              ),

              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScannerHeader(state: _state),
                    const SizedBox(height: 24),

                    CableDetectedBanner(
                      isScanning: _state.isScanning,
                      isWarning: isWarning,
                    ),

                    Center(
                      child: CircularGauge(
                        value: current.deltaMagnitude,
                        threshold: _state.warningThreshold,
                        isScanning: _state.isScanning,
                        maxExpected: 160.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    CalibrationPanel(state: _state),
                    const SizedBox(height: 24),

                    VectorReadoutCard(state: _state, current: current),
                    const SizedBox(height: 20),

                    const OscilloscopeHeader(),
                    const SizedBox(height: 8),
                    OscilloscopeChart(
                      history: _state.history,
                      threshold: _state.warningThreshold,
                      isScanning: _state.isScanning,
                      maxVal: 160.0,
                    ),
                    const SizedBox(height: 24),

                    ScannerControlsCard(
                      state: _state,
                      wakeLockActive: _wakeLockActive,
                      onToggleWakeLock: _toggleWakeLock,
                    ),
                    const SizedBox(height: 24),

                    SimulatorLabCard(state: _state),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
