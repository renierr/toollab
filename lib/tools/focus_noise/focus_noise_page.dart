import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/database_service.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'config.dart';
import 'engine/focus_noise_player.dart';
import 'focus_noise_breathing.dart';
import 'focus_noise_sound.dart';
import 'widgets/focus_noise_cards.dart';

class FocusNoisePage extends StatefulWidget {
  const FocusNoisePage({super.key});

  @override
  State<FocusNoisePage> createState() => _FocusNoisePageState();
}

class _FocusNoisePageState extends State<FocusNoisePage> with DisposeCleanup {
  static String get _toolId => FocusNoiseTool.config.id;
  static const String _keySound = 'selected_sound';
  static const String _keyVolume = 'volume';
  static const String _keyBreathingMode = 'breathing_mode';
  static const String _keyTimerCustomMinutes = 'timer_custom_minutes';

  final FocusNoisePlayer _player = FocusNoisePlayer();

  FocusNoiseSound _selectedSound = FocusNoiseCatalog.sounds.first;
  double _volume = 0.65;
  bool _isPlaying = false;

  Timer? _timerTicker;
  DateTime? _timerTarget;
  int _customMinutes = 30;

  bool _breathingActive = false;
  WakeLockLease? _breathingWakeLock;
  FocusBreathingMode _breathingMode = FocusBreathingMode.relax;
  Timer? _breathingTimer;
  int _breathingStepIndex = 0;
  String? _breathingStepLabel;
  double _breathingScale = 1.0;
  Duration _breathingAnimDuration = const Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _player.onExternalStop = _onPlayerExternalStop;
    onDispose(() => _player.dispose());
    onDispose(() => _timerTicker?.cancel());
    onDispose(() => _breathingTimer?.cancel());
    onDispose(() => _breathingWakeLock?.release());
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSettings());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    _player.notificationTitle = l10n.focusNotificationTitle;
    _player.notificationText = l10n.focusNotificationText;
  }

  Future<void> _restoreSettings() async {
    final db = DatabaseService.instance;
    final soundId = await db.getSetting(_toolId, _keySound);
    final volumeRaw = await db.getSetting(_toolId, _keyVolume);
    final modeRaw = await db.getSetting(_toolId, _keyBreathingMode);
    final customRaw = await db.getSetting(_toolId, _keyTimerCustomMinutes);

    if (!mounted) return;
    setState(() {
      if (soundId != null && soundId.isNotEmpty) {
        _selectedSound = FocusNoiseCatalog.byId(soundId);
      }
      _volume = double.tryParse(volumeRaw ?? '')?.clamp(0.0, 1.0) ?? 0.65;
      _breathingMode = switch (modeRaw) {
        'box' => FocusBreathingMode.box,
        'calm' => FocusBreathingMode.calm,
        _ => FocusBreathingMode.relax,
      };
      _customMinutes = int.tryParse(customRaw ?? '')?.clamp(1, 1440) ?? 30;
    });
    _player.setVolume(_volume);
  }

  Future<void> _selectSound(FocusNoiseSound sound) async {
    setState(() => _selectedSound = sound);
    await DatabaseService.instance.setSetting(_toolId, _keySound, sound.id);
    if (_isPlaying) {
      await _player.play(sound);
      _player.setVolume(_volume);
    }
  }

  void _onPlayerExternalStop() {
    if (!mounted) return;
    if (_breathingActive) {
      _toggleBreathing();
    }
    _timerTarget = null;
    _timerTicker?.cancel();
    setState(() => _isPlaying = false);
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.stop();
      if (_breathingActive) {
        _toggleBreathing();
      }
      _timerTarget = null;
      _timerTicker?.cancel();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
      return;
    }

    await _player.play(_selectedSound);
    _player.setVolume(_volume);
    if (!mounted) return;
    setState(() => _isPlaying = true);
  }

  Future<void> _setVolume(double value) async {
    setState(() => _volume = value);
    _player.setVolume(value);
    await DatabaseService.instance.setSetting(
      _toolId,
      _keyVolume,
      value.toStringAsFixed(3),
    );
  }

  void _setTimerMinutes(int minutes) {
    if (!_isPlaying) return;
    final int clamped = minutes.clamp(1, 1440);
    setState(() {
      _timerTarget = DateTime.now().add(Duration(minutes: clamped));
      _customMinutes = clamped;
    });
    DatabaseService.instance.setSetting(
      _toolId,
      _keyTimerCustomMinutes,
      clamped.toString(),
    );

    _timerTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final target = _timerTarget;
      if (target == null) return;
      final remaining = target.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _togglePlayback();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  void _cancelTimer() {
    setState(() => _timerTarget = null);
  }

  String _timerLabel() {
    final l10n = AppLocalizations.of(context);
    final target = _timerTarget;
    if (target == null) return l10n.focusNoTimerSet;
    final Duration remaining = target.difference(DateTime.now());
    if (remaining <= Duration.zero) return l10n.focusStopping;
    final int minutes = remaining.inMinutes;
    final int seconds = remaining.inSeconds % 60;
    final String time =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return l10n.focusWillStopIn(time);
  }

  Future<void> _setBreathingMode(FocusBreathingMode mode) async {
    setState(() {
      _breathingMode = mode;
      _breathingStepIndex = 0;
    });
    await DatabaseService.instance.setSetting(
      _toolId,
      _keyBreathingMode,
      switch (mode) {
        FocusBreathingMode.box => 'box',
        FocusBreathingMode.relax => 'relax',
        FocusBreathingMode.calm => 'calm',
      },
    );
    if (_breathingActive) {
      _runBreathingStep(restart: true);
    }
  }

  void _toggleBreathing() {
    setState(() => _breathingActive = !_breathingActive);
    if (_breathingActive) {
      unawaited(
        PowerWakeLockService.acquireFull().then((lease) {
          _breathingWakeLock = lease;
        }),
      );
      _runBreathingStep(restart: true);
      return;
    }

    _breathingWakeLock?.release();
    _breathingWakeLock = null;
    _breathingTimer?.cancel();
    _breathingTimer = null;
    setState(() {
      _breathingStepLabel = AppLocalizations.of(context).focusReady;
      _breathingScale = 1.0;
      _breathingAnimDuration = const Duration(milliseconds: 350);
    });
  }

  void _runBreathingStep({bool restart = false}) {
    _breathingTimer?.cancel();
    final FocusBreathingPattern pattern = FocusBreathingCatalog.byMode(
      _breathingMode,
    );
    if (restart) {
      _breathingStepIndex = 0;
    }
    final BreathingStep step =
        pattern.steps[_breathingStepIndex % pattern.steps.length];

    setState(() {
      _breathingStepLabel = step.localizedLabel(AppLocalizations.of(context));
      _breathingScale = step.scale;
      _breathingAnimDuration = step.duration;
    });

    _breathingTimer = Timer(step.duration, () {
      if (!_breathingActive) return;
      _breathingStepIndex = (_breathingStepIndex + 1) % pattern.steps.length;
      _runBreathingStep();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String statusText = _isPlaying
        ? l10n.focusPlayingSound(_selectedSound.name)
        : l10n.focusSelectedSound(_selectedSound.name);

    final Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FocusNoiseCards(
        statusText: statusText,
        selectedSound: _selectedSound,
        isPlaying: _isPlaying,
        volume: _volume,
        timerTarget: _timerTarget,
        timerLabel: _timerLabel(),
        customMinutes: _customMinutes,
        breathingMode: _breathingMode,
        breathingActive: _breathingActive,
        breathingStepLabel: _breathingStepLabel ?? l10n.focusReady,
        breathingScale: _breathingScale,
        breathingAnimDuration: _breathingAnimDuration,
        onSelectSound: _selectSound,
        onVolumeChanged: _setVolume,
        onTogglePlay: _togglePlayback,
        onCustomMinutesDecrement: () {
          setState(() => _customMinutes = (_customMinutes - 1).clamp(1, 1440));
        },
        onCustomMinutesIncrement: () {
          setState(() => _customMinutes = (_customMinutes + 1).clamp(1, 1440));
        },
        onSetPresetMinutes: _setTimerMinutes,
        onSetCustomTimer: () => _setTimerMinutes(_customMinutes),
        onCancelTimer: _cancelTimer,
        onBreathingModeChanged: _setBreathingMode,
        onToggleBreathing: _toggleBreathing,
      ),
    );

    return ToolLayout(
      title: FocusNoiseTool.config.localizedName(l10n),
      child: content,
    );
  }
}
