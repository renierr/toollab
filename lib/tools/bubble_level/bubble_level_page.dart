import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/responsive_orientation_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'config.dart';
import 'bubble_level_sensor.dart';
import 'widgets/bubble_level_view_2d.dart';
import 'widgets/bubble_level_view_1d.dart';
import 'widgets/bubble_level_readout.dart';
import 'widgets/bubble_level_toolbar.dart';
import 'widgets/bubble_level_ruler.dart';

class BubbleLevelPage extends StatefulWidget {
  const BubbleLevelPage({super.key});

  @override
  State<BubbleLevelPage> createState() => _BubbleLevelPageState();
}

class _BubbleLevelPageState extends State<BubbleLevelPage>
    with DisposeCleanup<BubbleLevelPage> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  final _sensor = BubbleLevelSensor();

  LevelMode _mode = LevelMode.mode2d;
  double _tolerance = 0.2;
  bool _locked = false;
  bool _rulerVisible = false;
  bool _rotationLocked = false;
  bool _wakeLocked = false;
  WakeLockLease? _fullWakeLock;
  double _pitch = 0;
  double _roll = 0;
  double _pxPerMm = 3.78;

  @override
  void initState() {
    super.initState();
    _startSensors();
    _loadSettings();
    onDispose(() => _subscription?.cancel());
    onDispose(() {
      final lease = _fullWakeLock;
      if (lease != null) {
        unawaited(lease.release());
      }
      _fullWakeLock = null;
    });
    onDispose(() {
      unawaited(
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    });
  }

  Future<void> _loadSettings() async {
    final db = DatabaseService.instance;
    final px = await db.getSetting(BubbleLevelTool.config.id, 'pxPerMm');
    final tol = await db.getSetting(BubbleLevelTool.config.id, 'tolerance');
    if (mounted) {
      setState(() {
        if (px != null) _pxPerMm = double.tryParse(px) ?? 3.78;
        if (tol != null) _tolerance = double.tryParse(tol) ?? 0.2;
      });
    }
  }

  Future<void> _savePxPerMm(double value) async {
    await DatabaseService.instance.setSetting(
      BubbleLevelTool.config.id,
      'pxPerMm',
      value.toStringAsFixed(4),
    );
  }

  Future<void> _saveTolerance(double value) async {
    await DatabaseService.instance.setSetting(
      BubbleLevelTool.config.id,
      'tolerance',
      value.toStringAsFixed(2),
    );
  }

  void _startSensors() {
    try {
      _subscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen(_onSensorEvent);
    } catch (e) {
      debugPrint('[BubbleLevel] Sensors not available: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.levelSensorsUnavailable)));
        }
      });
    }
  }

  void _onSensorEvent(AccelerometerEvent event) {
    if (mounted) {
      _sensor.setUiOrientation(MediaQuery.of(context).orientation);
    }
    final reading = _sensor.process(event);
    final pitch = BubbleLevelSensor.roundToOne(reading.pitch);
    final roll = BubbleLevelSensor.roundToOne(reading.roll);
    final locked = BubbleLevelSensor.isLevel(pitch, roll, _tolerance);

    setState(() {
      _pitch = pitch;
      _roll = roll;
      _locked = locked;
    });
  }

  void _onSetZero() {
    final l10n = AppLocalizations.of(context);
    _sensor.calibrateZero(_sensor.currentReading);
    setState(() {
      _pitch = 0;
      _roll = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.levelCalibratedToZero),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onResetZero() {
    final l10n = AppLocalizations.of(context);
    _sensor.resetCalibration();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.levelCalibrationReset),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onToggleRotationLock() {
    setState(() => _rotationLocked = !_rotationLocked);
    if (_rotationLocked) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _onToggleWakeLock() async {
    final target = !_wakeLocked;
    if (target) {
      _fullWakeLock ??= await PowerWakeLockService.acquireFull();
    } else {
      final lease = _fullWakeLock;
      if (lease != null) {
        await lease.release();
      }
      _fullWakeLock = null;
    }
    if (!mounted) return;
    setState(() => _wakeLocked = target);
  }

  Future<void> _onCalibrateRuler() async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => RulerCalibrationDialog(
        initialPxPerMm: _pxPerMm,
        onChanged: (v) => setState(() => _pxPerMm = v),
      ),
    );
    if (result != null) {
      setState(() => _pxPerMm = result);
      _savePxPerMm(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    _sensor.setUiOrientation(MediaQuery.of(context).orientation);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    final normalizedPitch = (_pitch / 20).clamp(-1.0, 1.0);
    final normalizedRoll = (_roll / 20).clamp(-1.0, 1.0);

    final toolbar = BubbleLevelToolbar(
      mode: _mode,
      tolerance: _tolerance,
      rulerVisible: _rulerVisible,
      rotationLocked: _rotationLocked,
      onModeChanged: (m) => setState(() => _mode = m),
      onToleranceChanged: (v) {
        setState(() => _tolerance = v);
        _saveTolerance(v);
      },
      onToggleRuler: () => setState(() => _rulerVisible = !_rulerVisible),
      onCalibrateRuler: _onCalibrateRuler,
      onSetZero: _onSetZero,
      onResetZero: _onResetZero,
      onToggleRotationLock: _onToggleRotationLock,
      wakeLocked: _wakeLocked,
      onToggleWakeLock: _onToggleWakeLock,
    );

    final view = _mode == LevelMode.mode2d
        ? BubbleLevelView2d(
            normalizedPitch: normalizedPitch,
            normalizedRoll: normalizedRoll,
            locked: _locked,
            accentColor: accentColor,
          )
        : BubbleLevelView1d(
            normalizedRoll: normalizedRoll,
            locked: _locked,
            accentColor: accentColor,
          );

    final readout = BubbleLevelReadout(pitch: _pitch, roll: _roll);

    final leftPadding = _rulerVisible ? 80.0 : 16.0;

    return ToolLayout(
      title: BubbleLevelTool.config.localizedName(l10n),
      fullscreen: true,
      showFloatingBackButton: false,
      child: Stack(
        children: [
          ResponsiveOrientationLayout(
            padding: EdgeInsets.fromLTRB(leftPadding, 8, 16, 8),
            landscape: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _mode == LevelMode.mode2d ? 1.0 : 2.5,
                      child: view,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [toolbar, const SizedBox(height: 12), readout],
                    ),
                  ),
                ),
              ],
            ),
            portrait: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    toolbar,
                    const SizedBox(height: 20),
                    Expanded(child: view),
                    const SizedBox(height: 16),
                    readout,
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          BubbleLevelRuler(visible: _rulerVisible, pixelsPerMm: _pxPerMm),
        ],
      ),
    );
  }
}
