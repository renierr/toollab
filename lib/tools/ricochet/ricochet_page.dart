import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/widgets/responsive_layout.dart';
import 'package:tool_lab/widgets/tool_layout.dart';
import 'engine/ricochet_audio.dart';
import 'engine/ricochet_engine.dart';
import 'engine/ricochet_strings.dart';
import 'config.dart';
import 'ricochet_colors.dart';
import 'ricochet_audio_service.dart';
import 'ricochet_state.dart';
import 'widgets/game_result_overlay.dart';
import 'widgets/power_menu_sheet.dart';
import 'widgets/ricochet_action_bar.dart';
import 'widgets/ricochet_board.dart';
import 'widgets/ricochet_hud.dart';

/// Ricochet's entry point: owns the engine, the frame clock and the page
/// chrome, and composes the board, HUD and overlays. All game logic lives in
/// the engine — this page only drives and presents it.
class RicochetPage extends StatefulWidget {
  const RicochetPage({super.key});

  @override
  State<RicochetPage> createState() => _RicochetPageState();
}

class _RicochetPageState extends State<RicochetPage>
    with
        SingleTickerProviderStateMixin,
        DisposeCleanup,
        WidgetsBindingObserver {
  final RicochetEngine _engine = RicochetEngine();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Keyboard play. Aim keys are polled per frame rather than driven by key
  /// repeat: the repeat rate is an OS setting, and a sight that lurches at
  /// whatever cadence the desktop happens to use is unaimable.
  final FocusNode _keyboard = FocusNode(debugLabel: 'ricochet');
  bool _focused = false;

  /// Radians per second the sight swings at, and the fine-aim divisor Shift
  /// applies — a full sweep in about a second and a half, or twelve with Shift.
  /// Fine aim is for placing a shot into a one-tile gap, so it is deliberately
  /// far slower than a scale factor you would guess at.
  static const double _aimSpeed = 2.1;
  static const double _fineAim = 0.12;

  Timer? _backgroundTicker;
  Timer? _idleTicker;

  static const Duration _idleFrameInterval = Duration(milliseconds: 100);

  /// The game-over panel's primary button, so the run's end can hand the
  /// keyboard over and taking it back on restart is one call.
  final FocusNode _overlayFocus = FocusNode(debugLabel: 'ricochet-over');
  bool _wasOver = false;

  /// Held only while a ball volley is actually in motion, so the screen can
  /// still sleep while the player sits idle lining up a shot.
  WakeLockLease? _wakeLock;
  bool _wakeLockWanted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    onDispose(() => WidgetsBinding.instance.removeObserver(this));
    onDispose(_ticker.dispose);
    onDispose(_keyboard.dispose);
    onDispose(_overlayFocus.dispose);
    _engine.hud.addListener(_syncOverlayFocus);
    onDispose(() => _engine.hud.removeListener(_syncOverlayFocus));
    onDispose(_stopBackgroundTicker);
    onDispose(_stopIdleTicker);
    onDispose(_engine.dispose);
    onDispose(RicochetAudioService.instance.stopLoop);
    onDispose(() => unawaited(RicochetAudioService.instance.releaseAll()));
    onDispose(_releaseWakeLock);
    unawaited(_bootstrap());
  }

  void _syncWakeLock() {
    final wanted = _engine.turnInProgress;
    if (wanted == _wakeLockWanted) return;
    _wakeLockWanted = wanted;
    if (wanted) {
      unawaited(
        PowerWakeLockService.acquireFull().then((lease) {
          if (mounted && _wakeLockWanted) {
            _wakeLock = lease;
          } else {
            unawaited(lease.release());
          }
        }),
      );
    } else {
      final lease = _wakeLock;
      _wakeLock = null;
      if (lease != null) unawaited(lease.release());
    }
  }

  /// Moves the keyboard between the board and the game-over panel. The panel
  /// is built by an [AnimatedBuilder] on the HUD beacon, so the page's own
  /// [Focus] never rebuilds with the run's end and cannot yield focus itself.
  void _syncOverlayFocus() {
    final over = _engine.mode == GameMode.over;
    if (over == _wasOver) return;
    _wasOver = over;
    // The panel is only in the tree after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (over ? _overlayFocus : _keyboard).requestFocus();
    });
  }

  Future<void> _bootstrap() async {
    await context.read<RicochetState>().restore();
    await RicochetSfx.load();
    await _engine.start();
    if (!mounted) return;
    if (context.read<RicochetState>().soundEnabled) {
      RicochetAudioService.instance.playLoop(RicochetSfx.bgm, volume: 0.10);
    }
    _lastTick = Duration.zero;
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The engine paints its own toasts and banners, so it needs the localized
    // text; rebuilding here picks up a locale switch without restarting a run.
    _engine.strings = _buildStrings(AppLocalizations.of(context));
  }

  RicochetStrings _buildStrings(AppLocalizations l10n) => RicochetStrings(
    pierceArmed: l10n.ricochetToastPierceArmed,
    bombArmed: l10n.ricochetToastBombArmed,
    recalled: l10n.ricochetToastRecalled,
    rowCleared: l10n.ricochetToastRowCleared,
    plusOneBall: l10n.ricochetToastPlusOneBall,
    dragToAim: l10n.ricochetHintDragToAim,
    pierceLabel: l10n.ricochetChipPierce,
    bombLabel: l10n.ricochetChipBomb,
    plusBalls: l10n.ricochetToastPlusBalls,
    speedBoost: l10n.ricochetToastSpeed,
    autoSpeed: l10n.ricochetToastAutoSpeed,
    levelBanner: l10n.ricochetBannerLevel,
    scorePopup: (points) => '+$points',
    scorePopupDoubled: l10n.ricochetPopupDoubled,
    chargeChip: (label, count) => count > 1 ? '$label ×$count' : label,
  );

  // ------------------------------------------------------------- frame driver

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final steeringAim = _steerAim(dt);
    // A frame longer than a fifth of a second is a stall, not slow motion.
    _engine.update(dt.clamp(0.0, 0.25));
    _syncWakeLock();
    if (!steeringAim && !_engine.needsFrame) {
      _ticker.stop();
      _startIdleTicker();
    }
  }

  void _wakeTicker() {
    _stopIdleTicker();
    _lastTick = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  // ------------------------------------------------------------- app lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _stopBackgroundTicker();
      _wakeTicker();
      if (context.read<RicochetState>().soundEnabled) {
        RicochetAudioService.instance.playLoop(RicochetSfx.bgm, volume: 0.10);
      }
    } else {
      _stopIdleTicker();
      RicochetAudioService.instance.stopLoop();
      unawaited(_engine.saveNow());
      // The screen is off or another app is shown either way, so the lock
      // itself is moot here — but drop it so state stays truthful for resume.
      _releaseWakeLock();
      if (_engine.turnInProgress) _startBackgroundTicker();
    }
  }

  void _releaseWakeLock() {
    _wakeLockWanted = false;
    final lease = _wakeLock;
    _wakeLock = null;
    if (lease != null) unawaited(lease.release());
  }

  void _startBackgroundTicker() {
    _backgroundTicker ??= Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
      _engine.update(0.2);
      if (!_engine.turnInProgress) _stopBackgroundTicker();
    });
  }

  void _stopBackgroundTicker() {
    _backgroundTicker?.cancel();
    _backgroundTicker = null;
  }

  void _startIdleTicker() {
    if (!_engine.hasPickups || _idleTicker != null) return;
    _idleTicker = Timer.periodic(_idleFrameInterval, (_) {
      _engine.update(_idleFrameInterval.inMilliseconds / 1000);
      if (!_engine.hasPickups || _engine.needsFrame) _stopIdleTicker();
    });
  }

  void _stopIdleTicker() {
    _idleTicker?.cancel();
    _idleTicker = null;
  }

  // ------------------------------------------------------------------ keyboard

  bool _steerAim(double dt) {
    if (!_focused || _engine.mode != GameMode.aiming) return false;
    final keys = HardwareKeyboard.instance;
    var turn = 0.0;
    if (keys.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft) ||
        keys.isLogicalKeyPressed(LogicalKeyboardKey.keyA)) {
      turn -= 1;
    }
    if (keys.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight) ||
        keys.isLogicalKeyPressed(LogicalKeyboardKey.keyD)) {
      turn += 1;
    }
    if (turn == 0) return false;
    _engine.rotateAim(
      turn * _aimSpeed * dt * (keys.isShiftPressed ? _fineAim : 1),
    );
    return true;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Once the run is over the panel owns the keyboard: claiming Space or the
    // arrows here would leave its buttons unreachable.
    if (_engine.mode == GameMode.over) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _wakeTicker();
      _engine.fireAimed();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      // Only while a shot is lined up, so Escape still means "leave" otherwise.
      if (!_engine.aiming) return KeyEventResult.ignored;
      _engine.cancelAim();
      _wakeTicker();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _wakeTicker();
      _engine.recallBalls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _wakeTicker();
      _engine.boostSpeed();
      return KeyEventResult.handled;
    }
    // The aim keys are read in [_steerAim]; claim them here so they never reach
    // focus traversal and move the highlight off the board mid-shot.
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyD) {
      _wakeTicker();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------- intent

  Future<void> _openPowerMenu() async {
    final power = await PowerMenuSheet.show(context, onHowToPlay: _showHelp);
    if (power != null) {
      _wakeTicker();
      _engine.usePower(power);
    }
    // A sheet or a HUD button takes the focus with it; take it back so the
    // keyboard keeps playing without a click on the board first.
    if (mounted) _keyboard.requestFocus();
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.ricochetHelpTitle),
          content: SingleChildScrollView(child: Text(l10n.ricochetHelpText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonClose),
            ),
          ],
        );
      },
    );
  }

  /// Restarts, then takes the keyboard back from the result panel's button so
  /// the next shot can be aimed without reaching for the mouse.
  Future<void> _restart(Future<void> Function() action) async {
    _wakeTicker();
    await action();
    if (mounted) _keyboard.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RicochetState>();
    RicochetAudioService.instance.setMasterVolume(state.soundEnabled ? 1 : 0);

    return ToolLayout(
      title: RicochetTool.config.localizedName(l10n),
      backgroundColor: RicochetColors.page,
      fullscreen: true,
      showFloatingBackButton: true,
      // Autofocus so a desktop player can aim the instant the page opens,
      // without clicking the board first. The node sits above the HUD, so a
      // button taking the focus keeps [hasFocus] true and keys keep working.
      child: Focus(
        autofocus: true,
        focusNode: _keyboard,
        onFocusChange: (focused) => _focused = focused,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hud = RicochetHud(
              engine: _engine,
              vertical: constraints.canSplit,
              onOpenPowers: _openPowerMenu,
              onRestartLevel: () => unawaited(_restart(_engine.retryLevel)),
            );

            final board = Stack(
              fit: StackFit.passthrough,
              children: [
                RicochetBoard(engine: _engine, onInteraction: _wakeTicker),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _engine.hud,
                    builder: (context, _) => _engine.mode == GameMode.over
                        ? GameResultOverlay(
                            primaryFocusNode: _overlayFocus,
                            title: l10n.ricochetGameOver,
                            headline: '${_engine.score}',
                            headlineColor: RicochetColors.bonus,
                            subtitle:
                                _engine.score >= _engine.best &&
                                    _engine.score > 0
                                ? l10n.ricochetNewBest
                                : l10n.ricochetBestScore(_engine.best),
                            footnote: l10n.ricochetReachedLevel(_engine.level),
                            scrimColor: RicochetColors.board,
                            autofocusPrimary: true,
                            actions: [
                              GameResultAction(
                                label: l10n.ricochetRetryLevel,
                                icon: Icons.replay_rounded,
                                onPressed: () => _restart(_engine.retryLevel),
                              ),
                              GameResultAction(
                                label: l10n.ricochetStartOver,
                                icon: Icons.restart_alt_rounded,
                                onPressed: () => _restart(_engine.resetGame),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            );

            // Wide enough for two panes: the HUD becomes a fixed column beside
            // the board, which is what stops a landscape phone from spending half
            // its height on a stats row.
            if (constraints.canSplit) {
              return Row(
                children: [
                  Expanded(child: Center(child: board)),
                  SizedBox(
                    width: math.min(220, constraints.maxWidth * 0.28),
                    child: Column(
                      children: [
                        Expanded(child: hud),
                        RicochetActionBar(engine: _engine),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                hud,
                Expanded(child: Center(child: board)),
                RicochetActionBar(engine: _engine),
              ],
            );
          },
        ),
      ),
    );
  }
}
