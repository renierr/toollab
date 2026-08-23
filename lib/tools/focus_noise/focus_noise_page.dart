import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/tool_layout.dart';

import 'package:provider/provider.dart';

import 'config.dart';
import 'engine/focus_noise_player.dart';
import 'focus_noise_breathing.dart';
import 'focus_noise_sound.dart';
import 'focus_noise_state.dart';
import 'widgets/focus_noise_cards.dart';

class FocusNoisePage extends StatefulWidget {
  const FocusNoisePage({super.key});

  @override
  State<FocusNoisePage> createState() => _FocusNoisePageState();
}

class _FocusNoisePageState extends State<FocusNoisePage> with DisposeCleanup {
  final FocusNoisePlayer _player = FocusNoisePlayer.instance;

  bool _isPlaying = false;

  Timer? _timerTicker;
  DateTime? _timerTarget;

  bool _breathingActive = false;
  WakeLockLease? _breathingWakeLock;
  Timer? _breathingTimer;
  int _breathingStepIndex = 0;
  String? _breathingStepLabel;
  double _breathingScale = 1.0;
  Duration _breathingAnimDuration = const Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    // Reuse the shared player and reflect any playback still running in the
    // background instead of tearing it down on page leave.
    _isPlaying = _player.isPlaying;
    _player.onExternalStop = _onPlayerExternalStop;
    _player.onExternalStateChange = _onPlayerExternalStateChange;
    onDispose(() => _player.onExternalStop = null);
    onDispose(() => _player.onExternalStateChange = null);
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
    _syncPlayerNotification();
  }

  /// Composes the notification body from the active sound and timer state and
  /// pushes it to the foreground lease.
  void _syncPlayerNotification() {
    if (!_player.isPlaying) return;
    final l10n = AppLocalizations.of(context);
    final name = context.read<FocusNoiseState>().selectedSound.name;
    _player.notificationText = _timerTarget != null
        ? _timerLabel()
        : (_player.isPaused
              ? l10n.focusPausedSound(name)
              : l10n.focusPlayingSound(name));
    _player.refreshNotification();
  }

  void _onPlayerExternalStateChange() {
    if (!mounted) return;
    setState(() {});
    _syncPlayerNotification();
  }

  Future<void> _restoreSettings() async {
    final settings = context.read<FocusNoiseState>();
    // When returning to an active session, keep the sound/volume that is
    // actually playing rather than the last persisted values.
    if (_player.isPlaying && _player.currentSound != null) {
      settings.adoptPlayback(_player.currentSound!, _player.volume);
    } else {
      await settings.restore();
      if (!_player.isPlaying) _player.setVolume(settings.volume);
    }
  }

  Future<void> _selectSound(FocusNoiseSound sound) async {
    final settings = context.read<FocusNoiseState>();
    settings.setSelectedSound(sound);
    if (_isPlaying) {
      await _player.play(sound);
      _player.setVolume(settings.volume);
      _syncPlayerNotification();
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

    final settings = context.read<FocusNoiseState>();
    await _player.play(settings.selectedSound);
    _player.setVolume(settings.volume);
    if (!mounted) return;
    setState(() => _isPlaying = true);
    _syncPlayerNotification();
  }

  Future<void> _setVolume(double value) async {
    context.read<FocusNoiseState>().setVolume(value);
    _player.setVolume(value);
  }

  void _setTimerMinutes(int minutes) {
    if (!_isPlaying) return;
    final int clamped = minutes.clamp(1, 1440);
    setState(() {
      _timerTarget = DateTime.now().add(Duration(minutes: clamped));
    });
    context.read<FocusNoiseState>().setCustomMinutes(clamped);
    _syncPlayerNotification();

    _timerTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final target = _timerTarget;
      if (target == null) return;
      final remaining = target.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _togglePlayback();
      } else {
        // Push the countdown into the notification once per minute; the UI
        // label refreshes every tick.
        if (remaining.inSeconds % 60 == 0) {
          _syncPlayerNotification();
        }
        if (mounted) setState(() {});
      }
    });
  }

  void _cancelTimer() {
    setState(() => _timerTarget = null);
    _syncPlayerNotification();
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
    setState(() => _breathingStepIndex = 0);
    context.read<FocusNoiseState>().setBreathingMode(mode);
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
      context.read<FocusNoiseState>().breathingMode,
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
    final settings = context.watch<FocusNoiseState>();
    final selectedSound = settings.selectedSound;
    final String statusText = !_isPlaying
        ? l10n.focusSelectedSound(selectedSound.name)
        : _player.isPaused
        ? l10n.focusPausedSound(selectedSound.name)
        : l10n.focusPlayingSound(selectedSound.name);

    final Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FocusNoiseCards(
        statusText: statusText,
        selectedSound: selectedSound,
        isPlaying: _isPlaying,
        volume: settings.volume,
        timerTarget: _timerTarget,
        timerLabel: _timerLabel(),
        customMinutes: settings.customMinutes,
        breathingMode: settings.breathingMode,
        breathingActive: _breathingActive,
        breathingStepLabel: _breathingStepLabel ?? l10n.focusReady,
        breathingScale: _breathingScale,
        breathingAnimDuration: _breathingAnimDuration,
        onSelectSound: _selectSound,
        onVolumeChanged: _setVolume,
        onTogglePlay: _togglePlayback,
        onCustomMinutesDecrement: () => settings.setCustomMinutes(
          (settings.customMinutes - 1).clamp(1, 1440),
        ),
        onCustomMinutesIncrement: () => settings.setCustomMinutes(
          (settings.customMinutes + 1).clamp(1, 1440),
        ),
        onSetPresetMinutes: _setTimerMinutes,
        onSetCustomTimer: () => _setTimerMinutes(settings.customMinutes),
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
