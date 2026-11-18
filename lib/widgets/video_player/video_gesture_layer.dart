import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:tool_lab/core/tool_page_state.dart';
import 'package:tool_lab/l10n/app_localizations.dart';

import 'video_backend.dart';
import 'video_gesture_badge.dart';
import 'video_player_settings.dart';
import 'video_system_channel.dart';

/// Touch on the video: a tap for the controls, a double tap per the settings,
/// a horizontal swipe skips, a vertical swipe sets the volume (brightness on
/// the left half on Android), a long press plays at 2× and a pinch zooms.
class VideoGestureLayer extends StatefulWidget {
  final VideoBackend backend;
  final VideoPlayerSettings settings;
  final bool live;
  final VideoBadgeController badge;

  /// A new value resets the zoom, e.g. for the next video in the folder.
  final Object? zoomKey;
  final VoidCallback onTap;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeekBy;
  final Widget Function(BuildContext context, double zoom, Offset pan) surface;

  /// Drawn over the surface; not rebuilt by zooming.
  final Widget overlay;

  const VideoGestureLayer({
    super.key,
    required this.backend,
    required this.settings,
    required this.live,
    required this.badge,
    required this.zoomKey,
    required this.onTap,
    required this.onTogglePlay,
    required this.onSeekBy,
    required this.surface,
    required this.overlay,
  });

  @override
  State<VideoGestureLayer> createState() => _VideoGestureLayerState();
}

class _VideoGestureLayerState extends State<VideoGestureLayer>
    with DisposeCleanup {
  static const double _swipeDistance = 48;
  static const double _swipeVelocity = 400;
  static const double _maxZoom = 4;
  static const double _holdSpeed = 2;

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

  VideoBackend get _backend => widget.backend;
  VideoPlayerSettings get _settings => widget.settings;
  Duration get _skipStep => _settings.skip;

  /// Android's media volume unless the settings pick the player's own.
  bool get _systemVolume =>
      Platform.isAndroid && _settings.volumeTarget == VideoVolumeTarget.system;

  @override
  void initState() {
    super.initState();
    onDispose(() {
      if (_brightnessChanged) unawaited(VideoSystemChannel.setBrightness(null));
    });
  }

  @override
  void didUpdateWidget(covariant VideoGestureLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.zoomKey != oldWidget.zoomKey) {
      _zoom = 1;
      _pan = Offset.zero;
    }
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
        final read = _drag == _Drag.brightness
            ? VideoSystemChannel.brightness()
            : _readVolume();
        unawaited(read.then((level) => _levelStart = level));
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
      widget.badge.flash(
        icon: Icons.zoom_in,
        label: AppLocalizations.of(
          context,
        ).videoPlayerZoom((next * 100).round()),
      );
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    final state = _backend.state.value;
    if (widget.live || !state.playing || state.speed >= _holdSpeed) return;
    _heldSpeed = state.speed;
    unawaited(_backend.setSpeed(_holdSpeed));
    widget.badge.flash(
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
    widget.badge.hide();
  }

  void _skip({required bool forward}) {
    widget.onSeekBy(forward ? _skipStep : -_skipStep);
    final l10n = AppLocalizations.of(context);
    final seconds = _skipStep.inSeconds;
    widget.badge.flash(
      icon: forward ? Icons.fast_forward : Icons.fast_rewind,
      label: forward
          ? l10n.videoPlayerForward(seconds)
          : l10n.videoPlayerBack(seconds),
      alignment: Alignment(forward ? 0.6 : -0.6, 0),
    );
  }

  /// Sides skip, the middle toggles playback.
  void _onDoubleTap() {
    final at = _doubleTapAt;
    final width = context.size?.width ?? 0;
    if (widget.live ||
        _settings.doubleTap == VideoDoubleTap.playPause ||
        at == null ||
        width <= 0) {
      widget.onTogglePlay();
      return;
    }
    final third = at.dx / width;
    if (third < 1 / 3) {
      _skip(forward: false);
    } else if (third > 2 / 3) {
      _skip(forward: true);
    } else {
      widget.onTogglePlay();
    }
  }

  Future<double> _readVolume() async =>
      _systemVolume ? VideoSystemChannel.volume() : _backend.state.value.volume;

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
    unawaited(VideoSystemChannel.setBrightness(brightness));
    widget.badge.flash(
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
    unawaited(
      _systemVolume
          ? VideoSystemChannel.setVolume(volume)
          : _backend.setVolume(volume),
    );
    widget.badge.flash(
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

  @override
  Widget build(BuildContext context) {
    final doubleTap = _settings.doubleTap != VideoDoubleTap.off;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
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
        children: [widget.surface(context, _zoom, _pan), widget.overlay],
      ),
    );
  }
}

/// What a one- or two-finger drag on the video is doing.
enum _Drag { undecided, none, skip, volume, brightness, pan, zoom }
