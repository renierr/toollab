import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
import 'package:tool_lab/pages/video_settings_page.dart';
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
import 'video_playlist.dart';
import 'video_resume_store.dart';
import 'video_system_channel.dart';

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
/// Space / K / Play toggles playback, left/right seek by the arrow step, J / L
/// skip, N / P or Page Down / Up step through the folder, M mutes, S copies the frame,
/// Esc / Backspace close, any other key shows the controls.
/// < / > change the speed. A tap shows the controls; a double tap follows the settings, a horizontal swipe skips,
/// a vertical swipe sets the volume (brightness on the left half on Android), a long press plays
/// at 2× and a pinch zooms. Skips use the video settings' length.
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

  /// Saves where the video was left and continues there next time.
  final VideoResumeStore? resumeStore;

  /// Offers previous / next over the other videos in a local file's folder.
  final bool browseFolder;

  const VideoPlayerPage({
    super.key,
    required this.source,
    this.title,
    this.loop = false,
    this.actions = const [],
    this.qualities = const [],
    this.live = false,
    this.settings = const VideoPlayerSettings(),
    this.resumeStore,
    this.browseFolder = false,
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
    VideoResumeStore? resumeStore,
    bool browseFolder = false,
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
          resumeStore: resumeStore,
          browseFolder: browseFolder,
        ),
      ),
    );
  }

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with DisposeCleanup {
  static const Duration _stallLimit = Duration(seconds: 8);
  static const double _swipeDistance = 48;
  static const double _swipeVelocity = 400;
  static const double _maxZoom = 4;
  static const double _holdSpeed = 2;
  static const List<double> _speeds = VideoPlayerSettings.speedOptions;
  static const MethodChannel _systemChannel = VideoSystemChannel.channel;
  static const Duration _saveInterval = Duration(seconds: 5);

  late VideoPlayerSettings _settings = widget.settings;
  late VideoBackend _backend = _createBackend();
  late Uri _source = widget.source;
  late String? _title = widget.title;
  List<VideoPlaylistItem> _playlist = const [];
  int _playlistIndex = -1;
  DateTime _lastSave = DateTime(0);
  bool _savedPlaying = false;
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
  Offset? _doubleTapAt;
  _Drag _drag = _Drag.undecided;
  Offset _dragStart = Offset.zero;
  Offset _dragTotal = Offset.zero;
  double? _levelStart;
  double _zoom = 1;
  double _zoomStart = 1;
  Offset _pan = Offset.zero;
  bool _brightnessChanged = false;
  double? _heldSpeed;
  Timer? _badgeTimer;
  bool _badgeVisible = false;
  IconData _badgeIcon = Icons.fast_forward;
  String _badgeLabel = '';
  Alignment _badgeAlignment = Alignment.center;
  double? _badgeLevel;

  Duration get _seekStep => _settings.skip;

  /// Where playback should continue: X serves some replay segments only at
  /// lower qualities, so a seek can stall forever on the chosen one.
  Duration? _resumeAt;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    _backend.state.addListener(_onState);
    if (widget.browseFolder) unawaited(_scanFolder());
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
      _saveProgress();
      if (Platform.isAndroid) _screenOn.set(false);
      if (_brightnessChanged) {
        unawaited(_systemChannel.invokeMethod<void>('setBrightness'));
      }
      unawaited(_backend.dispose());
      _keyFocus.dispose();
      _playFocus.dispose();
    });
  }

  VideoBackend _createBackend() => VideoBackend.create(_settings);

  Future<void> _open() async {
    final start = await _resumeStart(widget.source);
    if (!mounted) return;
    final opening = _backend.open(
      widget.source,
      loop: widget.loop,
      start: start,
    );
    // Android builds its view from the controller that open() just created.
    setState(() {});
    await opening;
    final speed = _settings.defaultSpeed;
    if (!widget.live && speed != 1 && mounted) await _backend.setSpeed(speed);
    if (start != null) _announceResume(start);
  }

  Future<Duration?> _resumeStart(Uri source) async {
    final store = widget.resumeStore;
    if (store == null || widget.live || !_settings.resumePlayback) return null;
    return store.resumePosition(source);
  }

  void _announceResume(Duration start) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.videoPlayerResumed(formatVideoTime(start))),
        action: SnackBarAction(
          label: l10n.videoPlayerStartOver,
          onPressed: () => unawaited(_seekTo(Duration.zero)),
        ),
      ),
    );
  }

  /// Throttled while playing; immediate on pause, end and close.
  void _saveProgress({VideoPlaybackState? state}) {
    final store = widget.resumeStore;
    final s = state ?? _backend.state.value;
    if (store == null || widget.live || !s.initialized) return;
    if (s.duration <= Duration.zero) return;
    final now = DateTime.now();
    if (state != null &&
        s.playing == _savedPlaying &&
        !s.completed &&
        now.difference(_lastSave) < _saveInterval) {
      return;
    }
    _lastSave = now;
    _savedPlaying = s.playing;
    unawaited(
      store.savePosition(
        source: _source,
        title: _title ?? _source.pathSegments.lastOrNull ?? '',
        position: s.completed ? s.duration : s.position,
        duration: s.duration,
      ),
    );
  }

  Future<void> _scanFolder() async {
    final items = await videoFolderPlaylist(widget.source);
    if (items.length < 2) return;
    final path = widget.source.toFilePath();
    final index = items.indexWhere((i) => i.source.toFilePath() == path);
    if (!mounted || index < 0) return;
    setState(() {
      _playlist = items;
      _playlistIndex = index;
    });
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _playlist.length || index == _playlistIndex) {
      return;
    }
    _saveProgress();
    final item = _playlist[index];
    final start = await _resumeStart(item.source);
    if (!mounted) return;
    setState(() {
      _playlistIndex = index;
      _title = item.title;
      _zoom = 1;
      _pan = Offset.zero;
    });
    _lastSave = DateTime(0);
    _session?.retitle(item.title);
    await _reopen(item.source, start: start ?? Duration.zero);
    if (start != null) _announceResume(start);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pip != null || _session != null) return;
    if (_settings.mediaControls) _startSession();
    if (!Platform.isAndroid) return;
    _pip = VideoPip(
      onAction: _onRemoteAction,
      onDismissed: () => unawaited(_close()),
      labels: _pipLabels(),
      autoEnter: _settings.pipOnLeave,
    )..active.addListener(_onPipChanged);
  }

  void _startSession() {
    _session = VideoMediaSession(
      title:
          _title ?? AppLocalizations.of(context).videoPlayerNotificationTitle,
      live: widget.live,
      onAction: _onRemoteAction,
    );
  }

  /// Applies changed settings to the open video.
  Future<void> _openSettings() async {
    _hideTimer?.cancel();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const VideoSettingsPage()));
    final next = await SettingsService.videoPlayerSettings();
    if (!mounted) return;
    final old = _settings;
    setState(() {
      _settings = next;
      _backend.settings = next;
    });
    if (next.mediaControls != old.mediaControls) {
      if (next.mediaControls) {
        _startSession();
      } else {
        final session = _session;
        _session = null;
        unawaited(session?.dispose());
      }
    }
    _pip?.reconfigure(autoEnter: next.pipOnLeave, labels: _pipLabels());
    _onState();
    if (next.hardwareDecoding != old.hardwareDecoding && !Platform.isAndroid) {
      await _reopen(_source);
    }
    _scheduleHide();
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

  Future<void> _switchQuality(VideoQuality quality, {Duration? start}) async {
    if (quality.source == _source) return;
    await _reopen(quality.source, start: start);
  }

  /// A fresh backend per source: the old view leaves the tree before its
  /// controller is disposed.
  Future<void> _reopen(Uri source, {Duration? start}) async {
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
    final opening = next.open(source, loop: widget.loop, start: position);
    next.state.addListener(_onState);
    setState(() {
      _source = source;
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
    _saveProgress(state: state);
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

  void _onScaleStart(ScaleStartDetails details) {
    _drag = details.pointerCount > 1 ? _Drag.zoom : _Drag.undecided;
    _dragStart = details.localFocalPoint;
    _dragTotal = Offset.zero;
    _zoomStart = _zoom;
    _levelStart = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1 && _drag != _Drag.zoom) {
      _drag = _Drag.zoom;
      _zoomStart = _zoom / details.scale;
    }
    _dragTotal += details.focalPointDelta;
    if (_drag == _Drag.undecided) {
      if (_dragTotal.distance < 4) return;
      _drag = _pickDrag();
      if (_drag == _Drag.volume || _drag == _Drag.brightness) {
        final brightness = _drag == _Drag.brightness;
        unawaited(
          (brightness ? _readBrightness() : _readVolume()).then(
            (level) => _levelStart = level,
          ),
        );
      }
    }
    switch (_drag) {
      case _Drag.zoom:
        _setZoom(_zoomStart * details.scale, details.focalPointDelta);
      case _Drag.pan:
        _setZoom(_zoom, details.focalPointDelta);
      case _Drag.volume:
        _dragVolume();
      case _Drag.brightness:
        _dragBrightness();
      case _Drag.undecided || _Drag.skip || _Drag.none:
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final drag = _drag;
    _drag = _Drag.undecided;
    if (drag == _Drag.zoom && _zoom < 1.05) _setZoom(1, Offset.zero);
    if (drag != _Drag.skip) return;
    final dx = _dragTotal.dx;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final far = dx.abs() >= _swipeDistance;
    if (!far && velocity.abs() < _swipeVelocity) return;
    _skip(forward: far ? dx > 0 : velocity > 0);
  }

  /// A zoomed video pans; otherwise the direction and side pick the gesture.
  _Drag _pickDrag() {
    if (_zoom > 1) return _Drag.pan;
    if (_dragTotal.dx.abs() > _dragTotal.dy.abs()) {
      return !widget.live && _settings.swipeSkip ? _Drag.skip : _Drag.none;
    }
    final width = context.size?.width ?? 0;
    final left = width > 0 && _dragStart.dx < width / 2;
    if (Platform.isAndroid && _settings.swipeBrightness && left) {
      return _Drag.brightness;
    }
    return _settings.swipeVolume ? _Drag.volume : _Drag.none;
  }

  /// Keeps the zoomed video covering the screen where it can.
  void _setZoom(double zoom, Offset delta) {
    final box = context.size;
    if (box == null || box.isEmpty) return;
    final next = zoom.clamp(1.0, _maxZoom);
    final aspect = _backend.state.value.aspectRatio;
    final fitted = box.aspectRatio > aspect
        ? Size(box.height * aspect, box.height)
        : Size(box.width, box.width / aspect);
    final limitX = math.max(0.0, (fitted.width * next - box.width) / 2);
    final limitY = math.max(0.0, (fitted.height * next - box.height) / 2);
    final pan = _pan + delta;
    setState(() {
      _zoom = next;
      _pan = Offset(
        pan.dx.clamp(-limitX, limitX),
        pan.dy.clamp(-limitY, limitY),
      );
    });
    if (_drag == _Drag.zoom) {
      _flashBadge(
        icon: Icons.zoom_in,
        label: AppLocalizations.of(
          context,
        ).videoPlayerZoom((next * 100).round()),
        alignment: Alignment.center,
      );
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    final state = _backend.state.value;
    if (widget.live || !state.playing || state.speed >= _holdSpeed) return;
    _heldSpeed = state.speed;
    unawaited(_backend.setSpeed(_holdSpeed));
    _flashBadge(
      icon: Icons.fast_forward,
      label: AppLocalizations.of(
        context,
      ).videoPlayerHoldSpeed(_holdSpeed.round()),
      alignment: const Alignment(0, -0.8),
      hold: true,
    );
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    final speed = _heldSpeed;
    if (speed == null) return;
    _heldSpeed = null;
    unawaited(_backend.setSpeed(speed));
    setState(() => _badgeVisible = false);
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
    bool hold = false,
  }) {
    _badgeTimer?.cancel();
    setState(() {
      _badgeIcon = icon;
      _badgeLabel = label;
      _badgeAlignment = alignment;
      _badgeLevel = level;
      _badgeVisible = true;
    });
    if (hold) return;
    _badgeTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _badgeVisible = false);
    });
  }

  /// Sides skip, the middle toggles playback.
  void _onDoubleTap() {
    final at = _doubleTapAt;
    final width = context.size?.width ?? 0;
    if (widget.live ||
        _settings.doubleTap == VideoDoubleTap.playPause ||
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
      Platform.isAndroid && _settings.volumeTarget == VideoVolumeTarget.system;

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

  Future<double> _readBrightness() async {
    try {
      return await _systemChannel.invokeMethod<double>('getBrightness') ?? 0.5;
    } catch (e) {
      errorLog('[VideoPlayerPage] getBrightness failed: $e');
      return 0.5;
    }
  }

  /// A drag over 60 % of the height covers the whole range.
  double? _draggedLevel() {
    final start = _levelStart;
    final height = context.size?.height ?? 0;
    if (start == null || height <= 0) return null;
    return (start - _dragTotal.dy / (height * 0.6)).clamp(0.0, 1.0);
  }

  void _dragBrightness() {
    final brightness = _draggedLevel();
    if (brightness == null) return;
    _brightnessChanged = true;
    unawaited(
      _systemChannel
          .invokeMethod<void>('setBrightness', {'value': brightness})
          .catchError(
            (Object e) =>
                errorLog('[VideoPlayerPage] setBrightness failed: $e'),
          ),
    );
    _flashBadge(
      icon: Icons.brightness_6,
      label: AppLocalizations.of(
        context,
      ).videoPlayerBrightness((brightness * 100).round()),
      alignment: const Alignment(-0.6, 0),
      level: brightness,
    );
  }

  void _dragVolume() {
    final volume = _draggedLevel();
    if (volume == null) return;
    unawaited(_writeVolume(volume));
    _flashBadge(
      icon: volume > 0 ? Icons.volume_up : Icons.volume_off,
      label: AppLocalizations.of(
        context,
      ).videoPlayerVolume((volume * 100).round()),
      alignment: Platform.isAndroid && _settings.swipeBrightness
          ? const Alignment(0.6, 0)
          : Alignment.center,
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
        title: _title,
        source: _source,
        duration: _backend.state.value.duration,
        info: _backend.streamInfo(),
      ).then((_) => _scheduleHide()),
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_settings.hideDelay, () {
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
    if (key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.pageDown ||
        (key == LogicalKeyboardKey.keyN && event is KeyDownEvent)) {
      unawaited(_playAt(_playlistIndex + 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaTrackPrevious ||
        key == LogicalKeyboardKey.pageUp ||
        (key == LogicalKeyboardKey.keyP && event is KeyDownEvent)) {
      unawaited(_playAt(_playlistIndex - 1));
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
      unawaited(_seekBy(-_settings.arrowSeek));
      if (_controlsVisible) _scheduleHide();
      return KeyEventResult.handled;
    }
    if (seeks && key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seekBy(_settings.arrowSeek));
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
    final doubleTap = _settings.doubleTap != VideoDoubleTap.off;
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
              onDoubleTapDown: doubleTap
                  ? (details) => _doubleTapAt = details.localPosition
                  : null,
              onDoubleTap: doubleTap ? _onDoubleTap : null,
              onLongPressStart: _onLongPressStart,
              onLongPressEnd: _onLongPressEnd,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ValueListenableBuilder<VideoPlaybackState>(
                    valueListenable: _backend.state,
                    builder: (context, state, view) => _VideoSurface(
                      frameKey: _frameKey,
                      state: state,
                      zoom: inPip ? 1 : _zoom,
                      pan: inPip ? Offset.zero : _pan,
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
                              title: _title,
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
                              onSettings: () => unawaited(_openSettings()),
                              playlistLabel: _playlist.isEmpty
                                  ? null
                                  : '${_playlistIndex + 1} / ${_playlist.length}',
                              onPrevious: _playlistIndex > 0
                                  ? () => unawaited(_playAt(_playlistIndex - 1))
                                  : null,
                              onNext: _playlistIndex < _playlist.length - 1
                                  ? () => unawaited(_playAt(_playlistIndex + 1))
                                  : null,
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
  final double zoom;
  final Offset pan;
  final Widget view;
  final String errorLabel;

  const _VideoSurface({
    required this.frameKey,
    required this.state,
    required this.zoom,
    required this.pan,
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
        ClipRect(
          child: Transform.translate(
            offset: pan,
            child: Transform.scale(
              scale: zoom,
              child: Center(
                child: AspectRatio(
                  aspectRatio: state.aspectRatio,
                  child: RepaintBoundary(key: frameKey, child: view),
                ),
              ),
            ),
          ),
        ),
        if (!state.initialized || state.buffering)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// What a one- or two-finger drag on the video is doing.
enum _Drag { undecided, none, skip, volume, brightness, pan, zoom }
