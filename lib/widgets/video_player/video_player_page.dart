import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';
import 'package:tool_lab/services/power_wake_lock_service.dart';

import 'video_backend.dart';
import 'video_controls.dart';

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

/// Full-screen player with touch, mouse, keyboard and TV-remote controls.
/// OK / Space / Play toggles playback, left/right seek while the controls are
/// hidden, any other key brings the controls back.
class VideoPlayerPage extends StatefulWidget {
  final Uri source;
  final String? title;
  final bool loop;
  final List<VideoPlayerAction> actions;

  const VideoPlayerPage({
    super.key,
    required this.source,
    this.title,
    this.loop = false,
    this.actions = const [],
  });

  static Future<void> open(
    BuildContext context, {
    required Uri source,
    String? title,
    bool loop = false,
    List<VideoPlayerAction> actions = const [],
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerPage(
          source: source,
          title: title,
          loop: loop,
          actions: actions,
        ),
      ),
    );
  }

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with DisposeCleanup {
  static const Duration _hideDelay = Duration(seconds: 3);
  static const Duration _seekStep = Duration(seconds: 10);

  late final VideoBackend _backend = VideoBackend.create();
  final FocusNode _keyFocus = FocusNode(debugLabel: 'VideoPlayerKeys');
  final FocusNode _playFocus = FocusNode(debugLabel: 'VideoPlayerPlay');
  final ScreenOnRequest _screenOn = ScreenOnRequest();
  Timer? _hideTimer;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    unawaited(_backend.open(widget.source, loop: widget.loop));
    _backend.state.addListener(_onState);
    onDispose(() {
      _hideTimer?.cancel();
      _backend.state.removeListener(_onState);
      if (Platform.isAndroid) _screenOn.set(false);
      unawaited(_backend.dispose());
      _keyFocus.dispose();
      _playFocus.dispose();
    });
    _scheduleHide();
  }

  void _onState() {
    final state = _backend.state.value;
    if (Platform.isAndroid) _screenOn.set(state.playing);
    if (!state.playing && !_controlsVisible) _showControls();
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

  Future<void> _seekBy(Duration delta) async {
    final state = _backend.state.value;
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (state.duration > Duration.zero && target > state.duration) {
      target = state.duration;
    }
    await _backend.seek(target);
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
    if (key == LogicalKeyboardKey.mediaFastForward) {
      unawaited(_seekBy(_seekStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaRewind) {
      unawaited(_seekBy(-_seekStep));
      return KeyEventResult.handled;
    }
    if (_controlsVisible) {
      _scheduleHide();
      return KeyEventResult.ignored;
    }
    // Controls hidden: the remote drives playback directly.
    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_seekBy(-_seekStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seekBy(_seekStep));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      return KeyEventResult.ignored;
    }
    _showControls();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              onDoubleTap: _togglePlay,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ValueListenableBuilder<VideoPlaybackState>(
                    valueListenable: _backend.state,
                    builder: (context, state, view) => _VideoSurface(
                      state: state,
                      view: view!,
                      errorLabel: l10n.videoPlayerFailed,
                    ),
                    child: _backend.buildView(context),
                  ),
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
                              unawaited(_backend.seek(position));
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
  final VideoPlaybackState state;
  final Widget view;
  final String errorLabel;

  const _VideoSurface({
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
          child: AspectRatio(aspectRatio: state.aspectRatio, child: view),
        ),
        if (!state.initialized || state.buffering)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
