import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/helpers/debug_log.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/pages/video_settings_page.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';
import 'package:tool_lab/services/settings_service.dart';
import 'package:tool_lab/widgets/tv_file_picker_dialog.dart';

import 'video_backend.dart';
import 'video_controls.dart';
import 'video_format.dart';
import 'video_frame_capture.dart';
import 'video_gesture_badge.dart';
import 'video_gesture_layer.dart';
import 'video_info_dialog.dart';
import 'video_keymap.dart';
import 'video_media_session.dart';
import 'video_pip.dart';
import 'video_player_settings.dart';
import 'video_player_types.dart';
import 'video_playlist.dart';
import 'video_progress_saver.dart';
import 'video_resume_store.dart';
import 'video_stall_watchdog.dart';
import 'video_surface.dart';
import 'video_sync_dialog.dart';
import 'video_thumbnailer.dart';

export 'video_player_types.dart';

/// Full-screen player with touch ([VideoGestureLayer]), mouse, keyboard and
/// TV-remote ([videoKeyCommand]) controls. The system media controls follow
/// playback; Android adds picture-in-picture.
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
  static const List<double> _speeds = VideoPlayerSettings.speedOptions;

  late VideoPlayerSettings _settings = widget.settings;
  late VideoBackend _backend = _createBackend();
  late Uri _source = widget.source;
  late String? _title = widget.title;
  List<VideoPlaylistItem> _playlist = const [];
  int _playlistIndex = -1;
  late final VideoProgressSaver? _saver =
      widget.resumeStore == null || widget.live
      ? null
      : VideoProgressSaver(widget.resumeStore!);
  late final VideoThumbnailer? _thumbnailer =
      widget.resumeStore == null || widget.live
      ? null
      : VideoThumbnailer(widget.resumeStore!);
  late final VideoStallWatchdog _stall = VideoStallWatchdog(onStall: _fallBack);
  final VideoBadgeController _badge = VideoBadgeController();
  final GlobalKey _frameKey = GlobalKey(debugLabel: 'VideoFrame');
  final FocusNode _keyFocus = FocusNode(debugLabel: 'VideoPlayerKeys');
  final FocusNode _playFocus = FocusNode(debugLabel: 'VideoPlayerPlay');
  final ScreenOnRequest _screenOn = ScreenOnRequest();
  Timer? _hideTimer;
  bool _controlsVisible = false;
  VideoPip? _pip;
  VideoMediaSession? _session;
  bool _pipSupported = false;
  bool _closing = false;
  double _unmutedVolume = 1;
  Duration _subtitleDelay = Duration.zero;
  Duration _audioDelay = Duration.zero;

  Duration get _seekStep => _settings.skip;

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
      _stall.cancel();
      _badge.dispose();
      _pip?.active.removeListener(_onPipChanged);
      unawaited(_pip?.dispose());
      unawaited(_session?.dispose());
      _backend.state.removeListener(_onState);
      _saveProgress(force: true);
      if (Platform.isAndroid) _screenOn.set(false);
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
  }

  Future<Duration?> _resumeStart(Uri source) async {
    final store = widget.resumeStore;
    if (store == null || widget.live || !_settings.resumePlayback) return null;
    return store.resumePosition(source);
  }

  void _saveProgress({bool force = false}) => _saver?.save(
    source: _source,
    title: _title ?? _source.pathSegments.lastOrNull ?? '',
    state: _backend.state.value,
    force: force,
  );

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
    _saveProgress(force: true);
    final item = _playlist[index];
    final start = await _resumeStart(item.source);
    if (!mounted) return;
    setState(() {
      _playlistIndex = index;
      _title = item.title;
      _subtitleDelay = Duration.zero;
      _audioDelay = Duration.zero;
    });
    _saver?.reset();
    _thumbnailer?.reset();
    _session?.retitle(item.title);
    await _reopen(item.source, start: start ?? Duration.zero);
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

  Future<void> _switchQuality(VideoQuality quality) async {
    if (quality.source == _source) return;
    await _reopen(quality.source);
  }

  /// A fresh backend per source: the old view leaves the tree before its
  /// controller is disposed.
  Future<void> _reopen(Uri source, {Duration? start}) async {
    final old = _backend;
    final position = widget.live
        ? null
        : start ?? _stall.resumeAt ?? old.state.value.position;
    _stall.cancel();
    _stall.resumeAt = position;
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
    final previous = old.state.value;
    await opening;
    if (previous.speed != 1) await next.setSpeed(previous.speed);
    if (previous.volume != 1) await next.setVolume(previous.volume);
    await _applyDelays(next);
  }

  Future<void> _applyDelays(VideoBackend backend) async {
    if (_subtitleDelay != Duration.zero) {
      await backend.setSubtitleDelay(_subtitleDelay);
    }
    if (_audioDelay != Duration.zero && backend.supportsAudioDelay) {
      await backend.setAudioDelay(_audioDelay);
    }
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
    _stall.watch(state);
    _saveProgress();
    _thumbnailer?.watch(
      source: _source,
      state: state,
      capture: () =>
          captureVideoThumbnail(backend: _backend, frameKey: _frameKey),
    );
    if ((state.completed || state.error != null) && !_controlsVisible) {
      _showControls();
    }
  }

  void _fallBack() {
    final lower = lowerVideoQuality(widget.qualities, _source);
    if (lower == null || !mounted) return;
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
    if (!widget.live) _stall.resumeAt = position;
    await _backend.seek(position);
    unawaited(
      _session?.seeked(position, playing: _backend.state.value.playing),
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

  /// Unmuting restores the volume from before muting.
  void _toggleMute() {
    final volume = _backend.state.value.volume;
    if (volume > 0) _unmutedVolume = volume;
    unawaited(_backend.setVolume(volume > 0 ? 0 : _unmutedVolume));
  }

  Future<void> _setSpeed(double speed) async {
    await _backend.setSpeed(speed);
    if (!mounted) return;
    _badge.flash(
      icon: Icons.speed,
      label: formatVideoSpeed(
        speed,
        l10n: AppLocalizations.of(context),
        locale: Localizations.localeOf(context).toString(),
      ),
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

  void _openSync() {
    _hideTimer?.cancel();
    final backend = _backend;
    unawaited(
      VideoSyncDialog.show(
        context,
        subtitleDelay: _subtitleDelay,
        audioDelay: _audioDelay,
        onSubtitleDelay: (delay) {
          _subtitleDelay = delay;
          unawaited(_backend.setSubtitleDelay(delay));
        },
        onAudioDelay: backend.supportsAudioDelay
            ? (delay) {
                _audioDelay = delay;
                unawaited(_backend.setAudioDelay(delay));
              }
            : null,
      ).then((_) => _scheduleHide()),
    );
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

  Future<void> _copyFrame() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final copied = await copyVideoFrame(
      backend: _backend,
      frameKey: _frameKey,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          copied ? l10n.widgetImageCopied : l10n.widgetImageCopyFailed,
        ),
      ),
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

  void _toggleControls() {
    if (_controlsVisible) {
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _togglePlay() async {
    if (_backend.state.value.playing) {
      await _backend.pause();
    } else {
      await _backend.play();
    }
    _showControls();
  }

  /// Runs the command after a control was used, so the controls stay up.
  void Function(T) _keepingControls<T>(void Function(T) command) => (value) {
    command(value);
    _scheduleHide();
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final command = videoKeyCommand(event);
    if (command == null) return KeyEventResult.ignored;
    if (_runKey(command)) return KeyEventResult.handled;
    if (_controlsVisible) {
      _scheduleHide();
      return KeyEventResult.ignored;
    }
    switch (command) {
      case VideoKeyCommand.select:
        unawaited(_togglePlay());
      case VideoKeyCommand.systemBack:
        return KeyEventResult.ignored;
      default:
        _showControls();
    }
    return KeyEventResult.handled;
  }

  /// False leaves the key to the controls: a paused player with the controls
  /// up moves between them with the arrows.
  bool _runKey(VideoKeyCommand command) {
    final live = widget.live;
    final arrowsSeek =
        !live && (!_controlsVisible || _backend.state.value.playing);
    switch (command) {
      case VideoKeyCommand.togglePlay:
        unawaited(_togglePlay());
      case VideoKeyCommand.play:
        unawaited(_backend.play());
      case VideoKeyCommand.pause:
        unawaited(_backend.pause());
      case VideoKeyCommand.next:
        unawaited(_playAt(_playlistIndex + 1));
      case VideoKeyCommand.previous:
        unawaited(_playAt(_playlistIndex - 1));
      case VideoKeyCommand.skipForward:
        unawaited(_seekBy(_seekStep));
      case VideoKeyCommand.skipBack:
        unawaited(_seekBy(-_seekStep));
      case VideoKeyCommand.copyFrame:
        unawaited(_copyFrame());
      case VideoKeyCommand.slower when !live:
        _stepSpeed(-1);
      case VideoKeyCommand.faster when !live:
        _stepSpeed(1);
      case VideoKeyCommand.toggleMute:
        _toggleMute();
      case VideoKeyCommand.close:
        unawaited(Navigator.of(context).maybePop());
      case VideoKeyCommand.arrowBack || VideoKeyCommand.arrowForward
          when arrowsSeek:
        final back = command == VideoKeyCommand.arrowBack;
        unawaited(_seekBy(back ? -_settings.arrowSeek : _settings.arrowSeek));
        if (_controlsVisible) _scheduleHide();
      default:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inPip = _pip?.active.value ?? false;
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
            child: VideoGestureLayer(
              backend: _backend,
              settings: _settings,
              live: widget.live,
              badge: _badge,
              zoomKey: _playlistIndex,
              onTap: _toggleControls,
              onTogglePlay: () => unawaited(_togglePlay()),
              onSeekBy: (delta) => unawaited(_seekBy(delta)),
              surface: (context, zoom, pan) =>
                  ValueListenableBuilder<VideoPlaybackState>(
                    valueListenable: _backend.state,
                    builder: (context, state, view) => VideoSurface(
                      frameKey: _frameKey,
                      state: state,
                      zoom: inPip ? 1 : zoom,
                      pan: inPip ? Offset.zero : pan,
                      view: view!,
                      errorLabel: l10n.videoPlayerFailed,
                    ),
                    child: KeyedSubtree(
                      key: ObjectKey(_backend),
                      child: _backend.buildView(context),
                    ),
                  ),
              overlay: inPip
                  ? const SizedBox.shrink()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoGestureBadge(controller: _badge),
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
                                  onSeekStart: () => _hideTimer?.cancel(),
                                  onSeek: _keepingControls(
                                    (position) => unawaited(_seekTo(position)),
                                  ),
                                  onSeekBy: _keepingControls(
                                    (delta) => unawaited(_seekBy(delta)),
                                  ),
                                  onToggleMute: _toggleMute,
                                  onClose: () =>
                                      Navigator.of(context).maybePop(),
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
                                  onQuality: _keepingControls(
                                    (q) => unawaited(_switchQuality(q)),
                                  ),
                                  speeds: _speeds,
                                  onSpeed: _keepingControls(
                                    (speed) => unawaited(_setSpeed(speed)),
                                  ),
                                  onAudioTrack: _keepingControls(
                                    (id) => unawaited(
                                      _backend.selectAudioTrack(id),
                                    ),
                                  ),
                                  onSubtitleTrack: _keepingControls<String?>(
                                    (id) => unawaited(
                                      _backend.selectSubtitleTrack(id),
                                    ),
                                  ),
                                  onLoadSubtitles: () =>
                                      unawaited(_loadSubtitles()),
                                  onSync: _openSync,
                                  onInfo: _showInfo,
                                  onSettings: () => unawaited(_openSettings()),
                                  playlistLabel: _playlist.isEmpty
                                      ? null
                                      : '${_playlistIndex + 1} / ${_playlist.length}',
                                  onPrevious: _playlistIndex > 0
                                      ? () => unawaited(
                                          _playAt(_playlistIndex - 1),
                                        )
                                      : null,
                                  onNext: _playlistIndex < _playlist.length - 1
                                      ? () => unawaited(
                                          _playAt(_playlistIndex + 1),
                                        )
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
