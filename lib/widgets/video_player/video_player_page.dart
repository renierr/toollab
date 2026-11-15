import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/clipboard_helper.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/widgets/tv_file_picker_dialog.dart';

import 'video_backend.dart';
import 'video_controls.dart';
import 'video_gesture_badge.dart';
import 'video_info_dialog.dart';
import 'video_media_session.dart';
import 'video_pip.dart';
import 'video_player_settings.dart';

class VideoPlayerAction {
  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext context) onPressed;

  const VideoPlayerAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// A rendition the viewer can switch to, e.g. one HLS variant.
class VideoQuality {
  final String label;
  final Uri source;

  /// A master playlist; never a stall fallback, mpv plays its best variant.
  final bool adaptive;

  const VideoQuality({
    required this.label,
    required this.source,
    this.adaptive = false,
  });
}

/// Full-screen player with touch, mouse, keyboard and TV-remote controls.
/// Space / K / Play toggles playback, left/right seek 5 s while playing, J / L
/// skip, M mutes, S copies the frame, Esc / Backspace close, any other key shows the controls.
/// < / > change the speed. A horizontal swipe or a side double tap skips,
/// a vertical swipe sets the volume. Skips use the video settings' length.
/// The system media controls follow playback; Android adds picture-in-picture.
class VideoPlayerPage extends StatefulWidget {
  static const String preferenceId = 'tool-lab-video-player';

  final Uri source;
  final String? title;
  final bool loop;
  final List<VideoPlayerAction> actions;

  /// Offered in a quality menu; [source] should be one of them.
  final List<VideoQuality> qualities;

  /// A live stream: no seek bar, no seeking.
  final bool live;
  final VideoPlayerSettings settings;

  const VideoPlayerPage({
    super.key,
    required this.source,
    this.title,
    this.loop = false,
    this.actions = const [],
    this.qualities = const [],
    this.live = false,
    this.settings = const VideoPlayerSettings(),
  });

  /// Loads the settings first: the backend needs them before it starts.

  static Future<void> open(
    BuildContext context, {
    required Uri source,
    String? title,
    bool loop = false,
    List<VideoPlayerAction> actions = const [],
    List<VideoQuality> qualities = const [],
    bool live = false,
  }) async {
    final settings = await SettingsService.videoPlayerSettings();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerPage(
          source: source,
          title: title,
          loop: loop,
          actions: actions,
          qualities: qualities,
          live: live,
          settings: settings,
        ),
      ),
    );
  }

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with DisposeCleanup {
  static const Duration _hideDelay = Duration(seconds: 3);
  static const Duration _arrowSeekStep = Duration(seconds: 5);
  static const Duration _stallLimit = Duration(seconds: 8);
  static const double _swipeDistance = 48;
  static const double _swipeVelocity = 400;
  static const List<double> _speeds = VideoPlayerSettings.speedOptions;
  static const MethodChannel _systemChannel = MethodChannel(
    'de.renier.tool_lab/video_system',
  );

  late VideoBackend _backend = _createBackend();
  late Uri _source = widget.source;
  final GlobalKey _frameKey = GlobalKey(debugLabel: 'VideoFrame');
  final FocusNode _keyFocus = FocusNode(debugLabel: 'VideoPlayerKeys');
  final FocusNode _playFocus = FocusNode(debugLabel: 'VideoPlayerPlay');
  final ScreenOnRequest _screenOn = ScreenOnRequest();
  Timer? _hideTimer;
  bool _controlsVisible = false;
  Timer? _stallTimer;
  VideoPip? _pip;
  VideoMediaSession? _session;
  bool _pipSupported = false;
  bool _closing = false;
  double _swipeDx = 0;
  Offset? _doubleTapAt;
  double? _volumeStart;
  double _volumeDy = 0;
  Timer? _badgeTimer;
  bool _badgeVisible = false;
  IconData _badgeIcon = Icons.fast_forward;
  String _badgeLabel = '';
  Alignment _badgeAlignment = Alignment.center;
  double? _badgeLevel;

  Duration get _seekStep => widget.settings.skip;

  /// Where playback should continue: X serves some replay segments only at
  /// lower qualities, so a seek can stall forever on the chosen one.
  Duration? _resumeAt;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    _backend.state.addListener(_onState);
    if (Platform.isAndroid) {
      unawaited(
        VideoPip.isSupported().then((supported) {
          if (mounted && supported) setState(() => _pipSupported = true);
        }),
      );
    }
    onDispose(() {
      _hideTimer?.cancel();
      _stallTimer?.cancel();
      _badgeTimer?.cancel();
      _pip?.active.removeListener(_onPipChanged);
      unawaited(_pip?.dispose());
      unawaited(_session?.dispose());
      _backend.state.removeListener(_onState);
      if (Platform.isAndroid) _screenOn.set(false);
      unawaited(_backend.dispose());
      _keyFocus.dispose();
      _playFocus.dispose();
    });
  }

  VideoBackend _createBackend() =>
      VideoBackend.create(hardwareDecoding: widget.settings.hardwareDecoding);

  Future<void> _open() async {
    await _backend.open(widget.source, loop: widget.loop);
    final speed = widget.settings.defaultSpeed;
    if (!widget.live && speed != 1 && mounted) await _backend.setSpeed(speed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pip != null || _session != null) return;
    final l10n = AppLocalizations.of(context);
    if (widget.settings.mediaControls) {
      _session = VideoMediaSession(
        title: widget.title ?? l10n.videoPlayerNotificationTitle,
        live: widget.live,
        onAction: _onRemoteAction,
      );
    }
    if (!Platform.isAndroid) return;
    _pip = VideoPip(
      onAction: _onRemoteAction,
      onDismissed: () => unawaited(_close()),
      labels: _pipLabels(),
      autoEnter: widget.settings.pipOnLeave,
    )..active.addListener(_onPipChanged);
  }

  Map<String, String> _pipLabels() {
    final l10n = AppLocalizations.of(context);
    final seconds = _seekStep.inSeconds;
    return {
      'play': l10n.videoPlayerPlay,
      'pause': l10n.videoPlayerPause,
      'rewind': l10n.videoPlayerBack(seconds),
      'forward': l10n.videoPlayerForward(seconds),
    };
  }

  /// A fresh backend per source: the old view leaves the tree before its
  /// controller is disposed.
  Future<void> _switchQuality(VideoQuality quality, {Duration? start}) async {
    if (quality.source == _source) return;
    final old = _backend;
    final position = widget.live
        ? null
        : start ?? _resumeAt ?? old.state.value.position;
    _stallTimer?.cancel();
    _stallTimer = null;
    _resumeAt = position;
    old.state.removeListener(_onState);
    final next = _createBackend();
    // Opening first: the Android backend builds its view from the controller
    // that open() creates synchronously.
    final opening = next.open(
      quality.source,
      loop: widget.loop,
      start: position,
    );
    next.state.addListener(_onState);
    setState(() {
      _source = quality.source;
      _backend = next;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(old.dispose()),
    );
    await opening;
    final speed = old.state.value.speed;
    if (speed != 1) await next.setSpeed(speed);
  }

  /// Controls appear on interaction only, plus at the end and on an error.
  void _onState() {
    final state = _backend.state.value;
    if (Platform.isAndroid) _screenOn.set(state.playing);
    unawaited(
      _pip?.update(
        playing: state.playing,
        seekable: !widget.live,
        aspectRatio: state.aspectRatio,
      ),
    );
    unawaited(_session?.sync(state));
    _watchStall(state);
    if ((state.completed || state.error != null) && !_controlsVisible) {
      _showControls();
    }
  }

  void _watchStall(VideoPlaybackState state) {
    final resumeAt = _resumeAt;
    final nearEnd =
        resumeAt != null &&
        state.duration > Duration.zero &&
        state.duration - resumeAt < const Duration(seconds: 10);
    final failed =
        resumeAt != null &&
        (state.error != null || (state.completed && !nearEnd));
    if (failed) {
      _fallBack();
      return;
    }
    final loading = !state.initialized || state.buffering;
    if (!loading || state.error != null) {
      _stallTimer?.cancel();
      _stallTimer = null;
      if (state.playing && state.initialized) _resumeAt = null;
      return;
    }
    _stallTimer ??= Timer(_stallLimit, _fallBack);
  }

  void _fallBack() {
    _stallTimer?.cancel();
    _stallTimer = null;
    final qualities = widget.qualities;
    final index = qualities.indexWhere((q) => q.source == _source);
    final lower = qualities
        .skip(index + 1)
        .where((q) => !q.adaptive)
        .firstOrNull;
    if (index < 0 || lower == null || !mounted) return;
    debugLog('[VideoPlayerPage] Stalled, falling back to ${lower.label}');
    unawaited(_switchQuality(lower));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).videoPlayerQualityFallback(lower.label),
        ),
      ),
    );
  }

  Future<void> _seekTo(Duration position) async {
    if (!widget.live) _resumeAt = position;
    await _backend.seek(position);
    unawaited(
      _session?.seeked(position, playing: _backend.state.value.playing),
    );
  }

  /// Notification, media key and picture-in-picture controls.
  void _onRemoteAction(String action) {
    switch (action) {
      case 'play':
        unawaited(_backend.play());
      case 'pause':
        unawaited(_backend.pause());
      case 'play_pause':
        unawaited(
          _backend.state.value.playing ? _backend.pause() : _backend.play(),
        );
      case 'rewind':
        unawaited(_seekBy(-_seekStep));
      case 'forward':
        unawaited(_seekBy(_seekStep));
      case 'stop':
        unawaited(_close());
      case _ when action.startsWith('seek:'):
        final ms = int.tryParse(action.substring('seek:'.length));
        if (ms != null) unawaited(_seekTo(Duration(milliseconds: ms)));
    }
  }

  void _onPipChanged() {
    if (!mounted) return;
    if (_pip!.active.value) {
      _hideTimer?.cancel();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _controlsVisible = false;
    }
    setState(() {});
  }

  Future<void> _enterPip() async {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = false);
    await _pip?.enter();
  }

  /// Leaves picture-in-picture first, or the window would show the page below.
  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _backend.pause();
    final pip = _pip;
    if (pip != null && pip.active.value) await pip.leave();
    if (!mounted) return;
    await Navigator.of(context).maybePop();
    _closing = false;
  }

  void _onSwipeEnd(DragEndDetails details) {
    final dx = _swipeDx;
    _swipeDx = 0;
    final velocity = details.primaryVelocity ?? 0;
    final far = dx.abs() >= _swipeDistance;
    if (!far && velocity.abs() < _swipeVelocity) return;
    final forward = far ? dx > 0 : velocity > 0;
    _skip(forward: forward);
  }

  void _skip({required bool forward}) {
    unawaited(_seekBy(forward ? _seekStep : -_seekStep));
    final l10n = AppLocalizations.of(context);
    _flashBadge(
      icon: forward ? Icons.fast_forward : Icons.fast_rewind,
      label: forward
          ? l10n.videoPlayerForward(_seekStep.inSeconds)
          : l10n.videoPlayerBack(_seekStep.inSeconds),
      alignment: Alignment(forward ? 0.6 : -0.6, 0),
    );
  }

  void _flashBadge({
    required IconData icon,
    required String label,
    required Alignment alignment,
    double? level,
  }) {
    _badgeTimer?.cancel();
    setState(() {
      _badgeIcon = icon;
      _badgeLabel = label;
      _badgeAlignment = alignment;
      _badgeLevel = level;
      _badgeVisible = true;
    });
    _badgeTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _badgeVisible = false);
    });
  }

  /// Sides skip, the middle toggles playback.
  void _onDoubleTap() {
    final at = _doubleTapAt;
    final width = context.size?.width ?? 0;
    if (widget.live ||
        widget.settings.doubleTap == VideoDoubleTap.playPause ||
        at == null ||
        width <= 0) {
      unawaited(_togglePlay());
      return;
    }
    final third = at.dx / width;
    if (third < 1 / 3) {
      _skip(forward: false);
    } else if (third > 2 / 3) {
      _skip(forward: true);
    } else {
      unawaited(_togglePlay());
    }
  }

  /// Android's media volume unless the settings pick the player's own.
  bool get _systemVolume =>
      Platform.isAndroid &&
      widget.settings.volumeTarget == VideoVolumeTarget.system;

  Future<double> _readVolume() async {
    if (!_systemVolume) return _backend.state.value.volume;
    try {
      return await _systemChannel.invokeMethod<double>('getVolume') ?? 0;
    } catch (e) {
      errorLog('[VideoPlayerPage] getVolume failed: $e');
      return 0;
    }
  }

  Future<void> _writeVolume(double volume) async {
    if (!_systemVolume) return _backend.setVolume(volume);
    try {
      await _systemChannel.invokeMethod<void>('setVolume', {'value': volume});
    } catch (e) {
      errorLog('[VideoPlayerPage] setVolume failed: $e');
    }
  }

  void _onVolumeStart(DragStartDetails _) {
    _volumeDy = 0;
    _volumeStart = null;
    unawaited(_readVolume().then((volume) => _volumeStart = volume));
  }

  /// A drag over 60 % of the height covers the whole range.
  void _onVolumeUpdate(DragUpdateDetails details) {
    _volumeDy -= details.delta.dy;
    final start = _volumeStart;
    final height = context.size?.height ?? 0;
    if (start == null || height <= 0) return;
    final volume = (start + _volumeDy / (height * 0.6)).clamp(0.0, 1.0);
    unawaited(_writeVolume(volume));
    _flashBadge(
      icon: volume > 0 ? Icons.volume_up : Icons.volume_off,
      label: AppLocalizations.of(
        context,
      ).videoPlayerVolume((volume * 100).round()),
      alignment: Alignment.center,
      level: volume,
    );
  }

  Future<void> _setSpeed(double speed) async {
    await _backend.setSpeed(speed);
    if (!mounted) return;
    _flashBadge(
      icon: Icons.speed,
      label: speed == 1
          ? AppLocalizations.of(context).videoPlayerSpeedNormal
          : '${NumberFormat('0.##', Localizations.localeOf(context).toString()).format(speed)}×',
      alignment: Alignment.center,
    );
  }

  void _stepSpeed(int direction) {
    final current = _speeds.indexWhere((s) => s >= _backend.state.value.speed);
    final index = (current < 0 ? _speeds.length - 1 : current) + direction;
    if (index < 0 || index >= _speeds.length) return;
    unawaited(_setSpeed(_speeds[index]));
  }

  /// Pauses first: leaving for the system picker would open picture-in-picture.
  Future<void> _loadSubtitles() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = _backend.state.value;
    final wasPlaying = state.playing;
    if (wasPlaying) {
      await _backend.pause();
      await _pip?.update(
        playing: false,
        seekable: !widget.live,
        aspectRatio: state.aspectRatio,
      );
    }
    if (!mounted) return;
    try {
      final file = await TvFilePickerDialog.openSingleFile(
        context,
        acceptedTypeGroups: [
          XTypeGroup(
            label: l10n.videoPlayerSubtitles,
            extensions: Platform.isAndroid
                ? null
                : const ['srt', 'vtt', 'ass', 'ssa'],
            mimeTypes: Platform.isAndroid ? const ['*/*'] : null,
          ),
        ],
      );
      if (file != null) await _backend.addSubtitleFile(file);
    } catch (e) {
      errorLog('[VideoPlayerPage] Subtitle load failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.videoPlayerSubtitleFailed)),
      );
    }
    if (wasPlaying && mounted) await _backend.play();
  }

  void _showInfo() {
    _hideTimer?.cancel();
    unawaited(
      VideoInfoDialog.show(
        context,
        title: widget.title,
        source: _source,
        duration: _backend.state.value.duration,
        info: _backend.streamInfo(),
      ).then((_) => _scheduleHide()),
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (!mounted || !_backend.state.value.playing) return;
      setState(() => _controlsVisible = false);
      _keyFocus.requestFocus();
    });
  }

  void _showControls() {
    if (!mounted) return;
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playFocus.requestFocus();
      });
    }
    _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final state = _backend.state.value;
    if (state.playing) {
      await _backend.pause();
    } else {
      await _backend.play();
    }
    _showControls();
  }

  /// Reads the video texture back through Flutter at the video's own size.
  /// mpv's screenshot cannot convert VA-API GPU frames.
  Future<void> _copyFrame() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    var copied = false;
    try {
      final native = await _backend.nativeFrame();
      final boundary =
          _frameKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (native != null) {
        copied = await ClipboardHelper.copyImageBytes(native);
      } else if (boundary != null && boundary.size.width > 0) {
        final videoWidth = _backend.state.value.videoWidth;
        final ratio = videoWidth != null
            ? videoWidth / boundary.size.width
            : devicePixelRatio;
        final image = await boundary.toImage(pixelRatio: ratio);
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png != null) {
            copied = await ClipboardHelper.copyImageBytes(
              png.buffer.asUint8List(),
              decoded: image,
            );
          }
        } finally {
          image.dispose();
        }
      }
    } catch (e) {
      errorLog('[VideoPlayerPage] Frame capture failed: $e');
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          copied ? l10n.widgetImageCopied : l10n.widgetImageCopyFailed,
        ),
      ),
    );
  }

  Future<void> _seekBy(Duration delta) async {
    if (widget.live) return;
    final state = _backend.state.value;
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (state.duration > Duration.zero && target > state.duration) {
      target = state.duration;
    }
    await _seekTo(target);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyK) {
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      unawaited(_backend.play());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      unawaited(_backend.pause());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.keyL) {
      unawaited(_seekBy(_seekStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.keyJ) {
      unawaited(_seekBy(-_seekStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && event is KeyDownEvent) {
      unawaited(_copyFrame());
      return KeyEventResult.handled;
    }
    if (!widget.live && event.character == '<') {
      _stepSpeed(-1);
      return KeyEventResult.handled;
    }
    if (!widget.live && event.character == '>') {
      _stepSpeed(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM && event is KeyDownEvent) {
      unawaited(_backend.setVolume(_backend.state.value.volume > 0 ? 0 : 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.browserBack) {
      unawaited(Navigator.of(context).maybePop());
      return KeyEventResult.handled;
    }
    // While playing, or with the controls hidden, arrows seek; a paused
    // player leaves them to move between the controls.
    final seeks =
        !widget.live && (!_controlsVisible || _backend.state.value.playing);
    if (seeks && key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_seekBy(-_arrowSeekStep));
      if (_controlsVisible) _scheduleHide();
      return KeyEventResult.handled;
    }
    if (seeks && key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seekBy(_arrowSeekStep));
      if (_controlsVisible) _scheduleHide();
      return KeyEventResult.handled;
    }
    if (_controlsVisible) {
      _scheduleHide();
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.goBack) return KeyEventResult.ignored;
    _showControls();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inPip = _pip?.active.value ?? false;
    final swipeSkip = !widget.live && widget.settings.swipeSkip;
    final swipeVolume = widget.settings.swipeVolume;
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _keyFocus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: MouseRegion(
            onHover: (_) => _showControls(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_controlsVisible) {
                  setState(() => _controlsVisible = false);
                } else {
                  _showControls();
                }
              },
              onDoubleTapDown: (details) =>
                  _doubleTapAt = details.localPosition,
              onDoubleTap: _onDoubleTap,
              onVerticalDragStart: swipeVolume ? _onVolumeStart : null,
              onVerticalDragUpdate: swipeVolume ? _onVolumeUpdate : null,
              onHorizontalDragStart: swipeSkip ? (_) => _swipeDx = 0 : null,
              onHorizontalDragUpdate: swipeSkip
                  ? (details) => _swipeDx += details.delta.dx
                  : null,
              onHorizontalDragEnd: swipeSkip ? _onSwipeEnd : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ValueListenableBuilder<VideoPlaybackState>(
                    valueListenable: _backend.state,
                    builder: (context, state, view) => _VideoSurface(
                      frameKey: _frameKey,
                      state: state,
                      view: view!,
                      errorLabel: l10n.videoPlayerFailed,
                    ),
                    child: KeyedSubtree(
                      key: ObjectKey(_backend),
                      child: _backend.buildView(context),
                    ),
                  ),
                  if (!inPip)
                    VideoGestureBadge(
                      visible: _badgeVisible,
                      alignment: _badgeAlignment,
                      icon: _badgeIcon,
                      label: _badgeLabel,
                      level: _badgeLevel,
                    ),
                  if (!inPip)
                    AnimatedOpacity(
                      opacity: _controlsVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: ExcludeFocus(
                          excluding: !_controlsVisible,
                          child: ValueListenableBuilder<VideoPlaybackState>(
                            valueListenable: _backend.state,
                            builder: (context, state, _) => VideoControls(
                              state: state,
                              title: widget.title,
                              playFocusNode: _playFocus,
                              actions: widget.actions,
                              onTogglePlay: _togglePlay,
                              onSeek: (position) {
                                unawaited(_seekTo(position));
                                _scheduleHide();
                              },
                              onSeekBy: (delta) {
                                unawaited(_seekBy(delta));
                                _scheduleHide();
                              },
                              onToggleMute: () =>
                                  _backend.setVolume(state.volume > 0 ? 0 : 1),
                              onClose: () => Navigator.of(context).maybePop(),
                              seekStep: _seekStep,
                              onCopyFrame: () {
                                unawaited(_copyFrame());
                                _scheduleHide();
                              },
                              onPictureInPicture: _pipSupported
                                  ? () => unawaited(_enterPip())
                                  : null,
                              live: widget.live,
                              qualities: widget.qualities,
                              source: _source,
                              onQuality: (q) {
                                unawaited(_switchQuality(q));
                                _scheduleHide();
                              },
                              speeds: _speeds,
                              onSpeed: (speed) {
                                unawaited(_setSpeed(speed));
                                _scheduleHide();
                              },
                              onAudioTrack: (id) {
                                unawaited(_backend.selectAudioTrack(id));
                                _scheduleHide();
                              },
                              onSubtitleTrack: (id) {
                                unawaited(_backend.selectSubtitleTrack(id));
                                _scheduleHide();
                              },
                              onLoadSubtitles: () =>
                                  unawaited(_loadSubtitles()),
                              onInfo: _showInfo,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  final GlobalKey frameKey;
  final VideoPlaybackState state;
  final Widget view;
  final String errorLabel;

  const _VideoSurface({
    required this.frameKey,
    required this.state,
    required this.view,
    required this.errorLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            errorLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: state.aspectRatio,
            child: RepaintBoundary(key: frameKey, child: view),
          ),
        ),
        if (!state.initialized || state.buffering)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
